onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/top_inst/cpu_wrdata
add wave -noupdate /tb/top_inst/cpu_rddata
add wave -noupdate /tb/top_inst/aqp_t80/bus_strobe
add wave -noupdate /tb/top_inst/clkctrl/dcm_locked
add wave -noupdate /tb/top_inst/clkctrl/clk_locked
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/clk
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/reset
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/clk_en
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/bus_wait
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/irq
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/nmi
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/bus_iorq
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/bus_no_read
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/bus_addr
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/bus_wrdata
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/mcycle
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/tstate
add wave -noupdate -group aqp_t80 -expand -group t80 -expand -group t80_if /tb/top_inst/aqp_t80/t80/irq_cycle
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_pc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_f
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_a_alt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_f_alt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_i
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_r
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_sp
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_bus_addr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_bus_wrdata
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_b
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_bus_c
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wren_h
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wren_l
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/bus_b
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/bus_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/d_auto_wait
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_alu_op
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_regs_alt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_memptr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_instruction
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_prefix
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_bus_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_tstate
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_mcycle
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_int_en1
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_int_en2
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_halt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_xy_state
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_im
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_no_btr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_btr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_auto_wait
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_inc_dec_is_zero
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_arith16
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_z16
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_save_alu
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_preserve_c
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_mcycles
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_irq_cycle
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi_cycle
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_read_to_reg
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_xy_ind
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/incdec16_result
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_arith16
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_call
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_exchange_rp
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_exchange_wh
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_inc_memptr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_inc_pc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_iorq
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_bc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_bt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_btr
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ccf
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_cpl
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_di
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_djnz
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ei
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ex_af
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ex_de_hl
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_exx
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_halt
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_inrc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_jp_ind_hl
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_ldsphl
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_retn
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_rld
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_rrd
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_is_scf
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_jump_e
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_jump
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_ldw
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_ldz
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_no_pc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_no_read
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_preserve_c
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_read_to_acc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_read_to_reg
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_rst_p
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_save_alu
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_write
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_xybit_undoc
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_im
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_prefix
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_sw
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_mcycles
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_addr_to
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_special_ld
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_tstates
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_alu_op
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_incdec16
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_bus_a_to
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/dec_set_bus_b_to
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_bitmask
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_do_sub
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_cin
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_addsub_l
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/addsub_m
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/addsub_h
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_half_carry
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_carry7
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_carry
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_addsub_result
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_overflow
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_result
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/alu_daa_tmp
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/d_reg_f
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/really_wait
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/t_reset
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/next_is_xy_fetch
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/save_mux
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_is_rld_rrd
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ioq1
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/ioq2
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/temp_n
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_b
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_reg_idx_c
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_idx_a
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_idx_b
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/reg_wrdata
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/regs_h
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/regs_l
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_nmi_pending
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q2_auto_wait
add wave -noupdate -group aqp_t80 -expand -group t80 -group t80_int /tb/top_inst/aqp_t80/t80/q_pre_xy_f_m
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/clk
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/reset
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_addr
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_wrdata
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_rddata
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_iorq
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_wren
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_strobe
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/bus_wait
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/irq
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/t80_noread
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/t80_mcycle
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/t80_tstate
add wave -noupdate -group aqp_t80 /tb/top_inst/aqp_t80/t80_irq_cycle
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
add wave -noupdate /tb/top_inst/q_reg_bank0
add wave -noupdate /tb/top_inst/q_reg_bank1
add wave -noupdate /tb/top_inst/q_reg_bank2
add wave -noupdate /tb/top_inst/q_reg_bank3
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/clk
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/reset
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/wrdata
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/wr_en
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/rddata
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/rd_en
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/empty
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/full
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/almost_full
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/q_wridx
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/q_rdidx
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/d_wridx
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/d_rdidx
add wave -noupdate -group {RX FIFO} /tb/top_inst/esp_uart/rx_fifo/count
add wave -noupdate -group UART /tb/top_inst/esp_uart/clk
add wave -noupdate -group UART /tb/top_inst/esp_uart/reset
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_data
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_wr
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_full
add wave -noupdate -group UART /tb/top_inst/esp_uart/rxfifo_data
add wave -noupdate -group UART /tb/top_inst/esp_uart/rxfifo_rd
add wave -noupdate -group UART /tb/top_inst/esp_uart/rxfifo_empty
add wave -noupdate -group UART /tb/top_inst/esp_uart/esp_tx
add wave -noupdate -group UART /tb/top_inst/esp_uart/esp_rx
add wave -noupdate -group UART /tb/top_inst/esp_uart/esp_rts
add wave -noupdate -group UART /tb/top_inst/esp_uart/esp_cts
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_cts
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_q
add wave -noupdate -group UART /tb/top_inst/esp_uart/tx_busy
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_empty
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_tx_start
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_tx_data
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_tx_state
add wave -noupdate -group UART /tb/top_inst/esp_uart/tx_valid
add wave -noupdate -group UART /tb/top_inst/esp_uart/txfifo_almost_full
add wave -noupdate -group UART /tb/top_inst/esp_uart/rx_data
add wave -noupdate -group UART /tb/top_inst/esp_uart/rx_valid
add wave -noupdate -group UART /tb/top_inst/esp_uart/rxfifo_full
add wave -noupdate -group UART /tb/top_inst/esp_uart/rxfifo_almost_full
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_rxfifo_wrdata
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_rxfifo_wr
add wave -noupdate -group UART /tb/top_inst/esp_uart/q_rx_escape
add wave -noupdate -expand -group SRAM /tb/sram/A
add wave -noupdate -expand -group SRAM /tb/sram/IO
add wave -noupdate -expand -group SRAM /tb/sram/CE_n
add wave -noupdate -expand -group SRAM /tb/sram/OE_n
add wave -noupdate -expand -group SRAM /tb/sram/WE_n
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1093588436 ps} 0} {{Cursor 2} {7556741 ps} 0}
quietly wave cursor active 2
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
WaveRestoreZoom {7383419 ps} {8204667 ps}
bookmark add wave bookmark0 {{0 ps} {212100032 ps}} 0
