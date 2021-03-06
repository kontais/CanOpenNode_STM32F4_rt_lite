/*
 * COPYRIGHT (C) 2013-2014, Shanghai Real-Thread Technology Co., Ltd
 *
 *  All rights reserved.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <os.h>
#include <rtcpu.h>

#include "zynq7000.h"
#include "gic.h"

extern os_task_t *os_current_task;
#ifdef RT_USING_FINSH
extern long list_task(void);
#endif

/**
 * this function will show registers of CPU
 *
 * @param regs the registers point
 */
void os_arch_show_register (struct os_arch_exp_stack *regs)
{
    printk("Execption:\n");
    printk("r00:0x%08x r01:0x%08x r02:0x%08x r03:0x%08x\n", regs->r0, regs->r1, regs->r2, regs->r3);
    printk("r04:0x%08x r05:0x%08x r06:0x%08x r07:0x%08x\n", regs->r4, regs->r5, regs->r6, regs->r7);
    printk("r08:0x%08x r09:0x%08x r10:0x%08x\n", regs->r8, regs->r9, regs->r10);
    printk("fp :0x%08x ip :0x%08x\n", regs->fp, regs->ip);
    printk("sp :0x%08x lr :0x%08x pc :0x%08x\n", regs->sp, regs->lr, regs->pc);
    printk("cpsr:0x%08x\n", regs->cpsr);
}

/**
 * When comes across an instruction which it cannot handle,
 * it takes the undefined instruction trap.
 *
 * @param regs system registers
 *
 * @note never invoke this function in application
 */
void os_arch_trap_undef(struct os_arch_exp_stack *regs)
{
    printk("undefined instruction:\n");
    os_arch_show_register(regs);
#ifdef RT_USING_FINSH
    list_task();
#endif
    os_arch_shutdown();
}

/**
 * The software interrupt instruction (SWI) is used for entering
 * Supervisor mode, usually to request a particular supervisor
 * function.
 *
 * @param regs system registers
 *
 * @note never invoke this function in application
 */
void os_arch_trap_swi(struct os_arch_exp_stack *regs)
{
    printk("software interrupt:\n");
    os_arch_show_register(regs);
#ifdef RT_USING_FINSH
    list_task();
#endif
    os_arch_shutdown();
}

/**
 * An abort indicates that the current memory access cannot be completed,
 * which occurs during an instruction prefetch.
 *
 * @param regs system registers
 *
 * @note never invoke this function in application
 */
void os_arch_trap_pabt(struct os_arch_exp_stack *regs)
{
    printk("prefetch abort:\n");
    os_arch_show_register(regs);
#ifdef RT_USING_FINSH
    list_task();
#endif
    os_arch_shutdown();
}

/**
 * An abort indicates that the current memory access cannot be completed,
 * which occurs during a data access.
 *
 * @param regs system registers
 *
 * @note never invoke this function in application
 */
void os_arch_trap_dabt(struct os_arch_exp_stack *regs)
{
    printk("data abort:");
    os_arch_show_register(regs);
#ifdef RT_USING_FINSH
    list_task();
#endif
    os_arch_shutdown();
}

/**
 * Normally, system will never reach here
 *
 * @param regs system registers
 *
 * @note never invoke this function in application
 */
void os_arch_trap_resv(struct os_arch_exp_stack *regs)
{
    printk("reserved trap:\n");
    os_arch_show_register(regs);
#ifdef RT_USING_FINSH
    list_task();
#endif
    os_arch_shutdown();
}

#define GIC_ACK_INTID_MASK                    0x000003ff

void os_arch_trap_irq()
{
    void *param;
    uint32_t ir;
    uint32_t fullir;
    rt_isr_handler_t isr_func;
    extern struct rt_irq_desc isr_table[];

    fullir = arm_gic_get_active_irq(0);
    ir = fullir & GIC_ACK_INTID_MASK;

    /* get interrupt service routine */
    isr_func = isr_table[ir].handler;
    if (isr_func) {
        param = isr_table[ir].param;
        /* turn to interrupt service routine */
        isr_func(ir, param);
    }

    /* end of interrupt */
    arm_gic_ack(0, fullir);
}

void os_arch_trap_fiq()
{
    void *param;
    uint32_t ir;
    uint32_t fullir;
    rt_isr_handler_t isr_func;
    extern struct rt_irq_desc isr_table[];

    fullir = arm_gic_get_active_irq(0);
    ir = fullir & GIC_ACK_INTID_MASK;

    /* get interrupt service routine */
    isr_func = isr_table[ir].handler;
    param = isr_table[ir].param;

    /* turn to interrupt service routine */
    isr_func(ir, param);

    /* end of interrupt */
    arm_gic_ack(0, fullir);
}

