;/*
; * File      : context_rvds.S
; * This file is part of RT-Thread RTOS
; * COPYRIGHT (C) 2006 - 2013, RT-Thread Development Team
; *
; * The license and distribution terms for this file may be
; * found in the file LICENSE in this distribution or at
; * http://www.rt-thread.org/license/LICENSE
; *
; * Change Logs:
; * Date           Author       Notes
; * 2013-07-09     aozima       enhancement hard fault exception handler.
; */

;/**
; * @addtogroup CORTEX-M3
; */
;/*@{*/

SCB_VTOR        EQU     0xE000ED08               ; Vector Table Offset Register
NVIC_INT_CTRL   EQU     0xE000ED04               ; interrupt control state register
NVIC_SYSPRI2    EQU     0xE000ED20               ; system priority register (2)
NVIC_PENDSV_PRI EQU     0x00FF0000               ; PendSV priority value (lowest)
NVIC_PENDSVSET  EQU     0x10000000               ; value to trigger PendSV exception

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    REQUIRE8
    PRESERVE8

    IMPORT interrupt_switch_flag
    IMPORT interrupt_switch_task_from
    IMPORT interrupt_switch_task_to

;/*
; * os_sr_t os_enter_critical();
; */
os_enter_critical    PROC
    EXPORT  os_enter_critical
    MRS     r0, PRIMASK
    CPSID   I
    BX      LR
    ENDP

;/*
; * void os_exit_critical(os_sr_t sr);
; */
os_exit_critical    PROC
    EXPORT  os_exit_critical
    MSR     PRIMASK, r0
    BX      LR
    ENDP

;/*
; * void os_arch_context_switch(rt_uint32 from, rt_uint32 to);
; * r0 --> from
; * r1 --> to
; */
os_arch_context_switch_interrupt
    EXPORT os_arch_context_switch_interrupt
os_arch_context_switch    PROC
    EXPORT os_arch_context_switch

    ; set interrupt_switch_flag to 1
    LDR     r2, =interrupt_switch_flag
    LDR     r3, [r2]
    CMP     r3, #1
    BEQ     _reswitch
    MOV     r3, #1
    STR     r3, [r2]

    LDR     r2, =interrupt_switch_task_from   ; set interrupt_switch_task_from
    STR     r0, [r2]

_reswitch
    LDR     r2, =interrupt_switch_task_to     ; set interrupt_switch_task_to
    STR     r1, [r2]

    LDR     r0, =NVIC_INT_CTRL              ; trigger the PendSV exception (causes context switch)
    LDR     r1, =NVIC_PENDSVSET
    STR     r1, [r0]
    BX      LR
    ENDP

; r0 --> switch from task stack
; r1 --> switch to task stack
; psr, pc, lr, r12, r3, r2, r1, r0 are pushed into [from] stack
PendSV_Handler   PROC
    EXPORT PendSV_Handler

    ; disable interrupt to protect context switch
    MRS     r2, PRIMASK
    CPSID   I

    ; get interrupt_switch_flag
    LDR     r0, =interrupt_switch_flag
    LDR     r1, [r0]
    CBZ     r1, pendsv_exit         ; pendsv already handled

    ; clear interrupt_switch_flag to 0
    MOV     r1, #0x00
    STR     r1, [r0]

    LDR     r0, =interrupt_switch_task_from
    LDR     r1, [r0]
    CBZ     r1, switch_to_task    ; skip register save at the first time

    MRS     r1, psp                 ; get from task stack pointer
    STMFD   r1!, {r4 - r11}         ; push r4 - r11 register
    LDR     r0, [r0]
    STR     r1, [r0]                ; update from task stack pointer

switch_to_task
    LDR     r1, =interrupt_switch_task_to
    LDR     r1, [r1]
    LDR     r1, [r1]                ; load task stack pointer

    LDMFD   r1!, {r4 - r11}         ; pop r4 - r11 register
    MSR     psp, r1                 ; update stack pointer

pendsv_exit
    ; restore interrupt
    MSR     PRIMASK, r2

    ORR     lr, lr, #0x04
    BX      lr
    ENDP

;/*
; * void os_arch_context_switch_to(rt_uint32 to);
; * r0 --> to
; * this fucntion is used to perform the first task switch
; */
os_arch_context_switch_to    PROC
    EXPORT os_arch_context_switch_to
    ; set to task
    LDR     r1, =interrupt_switch_task_to
    STR     r0, [r1]

    ; set from task to 0
    LDR     r1, =interrupt_switch_task_from
    MOV     r0, #0x0
    STR     r0, [r1]

    ; set interrupt flag to 1
    LDR     r1, =interrupt_switch_flag
    MOV     r0, #1
    STR     r0, [r1]

    ; set the PendSV exception priority
    LDR     r0, =NVIC_SYSPRI2
    LDR     r1, =NVIC_PENDSV_PRI
    LDR.W   r2, [r0,#0x00]       ; read
    ORR     r1,r1,r2             ; modify
    STR     r1, [r0]             ; write-back

    ; trigger the PendSV exception (causes context switch)
    LDR     r0, =NVIC_INT_CTRL
    LDR     r1, =NVIC_PENDSVSET
    STR     r1, [r0]

    ; restore MSP
    LDR     r0, =SCB_VTOR
    LDR     r0, [r0]
    LDR     r0, [r0]
    MSR     msp, r0

    ; enable interrupts at processor level
    CPSIE   I

    ; never reach here!
    ENDP

    IMPORT os_arch_hard_fault_exception
    EXPORT HardFault_Handler
HardFault_Handler    PROC

    ; get current context
    TST     lr, #0x04               ; if (!EXC_RETURN[2])
    MRSNE   r0, msp                 ; get fault context from handler.
    MRSEQ   r0, psp                 ; get fault context from task.

    STMFD   r0!, {r4 - r11}         ; push r4 - r11 register
    STMFD   r0!, {lr}               ; push exec_return register

    MSRNE   msp, r0                 ; update stack pointer to MSP.
    MSREQ   psp, r0                 ; update stack pointer to PSP.

    PUSH    {lr}
    BL      os_arch_hard_fault_exception
    POP     {lr}

    ORR     lr, lr, #0x04
    BX      lr
    ENDP

    ALIGN   4

    END
