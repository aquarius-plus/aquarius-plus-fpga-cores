onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/top_inst/cpu_wrdata
add wave -noupdate /tb/top_inst/cpu_rddata
add wave -noupdate /tb/top_inst/aqp_t80/my_strobe
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/clk
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/reset
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/clk_en
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/bus_wait
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/irq
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/nmi
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/bus_iorq
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/bus_no_read
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/bus_addr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/DInst
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/DI
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/bus_wrdata
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/mcycle
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/tstate
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_if /tb/top_inst/aqp_t80/t80/irq_cycle
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_pc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_f
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_a_alt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_f_alt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_i
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_r
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_sp
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_bus_addr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_bus_wrdata
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_b
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_c
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wren_h
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wren_l
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/bus_b
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/bus_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/d_auto_wait
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_alu_op
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_regs_alt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_memptr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_instruction
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_prefix
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_bus_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_tstate
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_mcycle
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_int_en1
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_int_en2
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_halt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_xy_state
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_im
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_no_btr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_btr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_auto_wait
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_inc_dec_is_zero
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_arith16
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_z16
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_save_alu
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_preserve_c
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_mcycles
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_irq_cycle
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi_cycle
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_read_to_reg
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_xy_ind
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/DI_Reg
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/incdec16_result
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/cc_is_true
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ir_ddd
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ir_sss
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ir_dpair
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_arith16
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_call
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_exchange_rp
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_exchange_wh
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_inc_memptr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_inc_pc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_iorq
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_bc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_bt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_btr
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ccf
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_cpl
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_di
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_djnz
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ei
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ex_af
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ex_de_hl
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_exx
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_halt
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_inrc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_jp_ind_hl
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ldsphl
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_retn
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_rld
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_rrd
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_scf
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_jump_e
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_jump
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_ldw
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_ldz
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_no_pc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_no_read
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_preserve_c
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_read_to_acc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_read_to_reg
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_rst_p
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_save_alu
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_write
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_xybit_undoc
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_im
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_prefix
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_sw
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_mcycles
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_addr_to
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_special_ld
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_tstates
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_alu_op
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_incdec16
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_bus_a_to
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_bus_b_to
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_bitmask
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_do_sub
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_cin
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_addsub_l
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/addsub_m
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/addsub_h
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_half_carry
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_carry7
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_carry
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_addsub_result
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_overflow
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_result
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_daa_tmp
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/d_reg_f
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/really_wait
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/t_reset
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/next_is_xy_fetch
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/save_mux
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_is_rld_rrd
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ioq1
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ioq2
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/temp_n
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_b
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_c
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_idx_a
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_idx_b
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wrdata
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/regs_h
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/regs_l
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi_pending
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q2_auto_wait
add wave -noupdate -expand -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_pre_xy_f_m
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/clk
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/reset
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_addr
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wrdata
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_rddata
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_iorq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wren
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_strobe
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wait
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/irq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_rd
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_bus_rd
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_bus_wr
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_phi
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/phi_rising
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/phi_falling
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_noread
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_mcycle
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_tstate
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_t80_di
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_irq_cycle
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/clk_en
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_wr_t2
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_req_inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_mreq_inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_read
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_mreq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_iorq_int
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_iorq_int_inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_iorq_t1
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_iorq_t2
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/mreq_rw
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/iorq_rw
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/clk
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/reset
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_addr
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_wrdata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_wren
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_strobe
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_wait
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/bus_rddata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/sram_a
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/sram_ce_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/sram_oe_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/sram_we_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/sram_dq
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_state
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_state
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_sram_a
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_sram_a
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_sram_we_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_sram_we_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_sram_oe_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_sram_oe_n
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_bus_wait
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_bus_wait
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_bus_rddata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_bus_rddata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_dq_wrdata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_dq_wrdata
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/d_dq_oe
add wave -noupdate -group {SRAM ctrl} /tb/top_inst/sram_ctrl/q_dq_oe
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3416140 ps} 0} {{Cursor 2} {639277345 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 364
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {87531250 ps} {100614517 ps}
bookmark add wave bookmark0 {{0 ps} {212100032 ps}} 0
