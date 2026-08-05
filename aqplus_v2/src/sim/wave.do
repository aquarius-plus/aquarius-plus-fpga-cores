onerror {resume}
quietly virtual function -install /tb/top_inst/t80 -env /tb/top_inst/t80 { &{/tb/top_inst/t80/clk, /tb/top_inst/t80/reset, /tb/top_inst/t80/clk_en, /tb/top_inst/t80/bus_addr, /tb/top_inst/t80/bus_wrdata, /tb/top_inst/t80/bus_wren, /tb/top_inst/t80/bus_iorq, /tb/top_inst/t80/bus_strobe, /tb/top_inst/t80/bus_wait, /tb/top_inst/t80/bus_rddata, /tb/top_inst/t80/irq, /tb/top_inst/t80/irq_vector, /tb/top_inst/t80/nmi, /tb/top_inst/t80/q_reg_pc, /tb/top_inst/t80/q_reg_a, /tb/top_inst/t80/q_reg_f, /tb/top_inst/t80/q_reg_a_alt, /tb/top_inst/t80/q_reg_f_alt, /tb/top_inst/t80/q_reg_i, /tb/top_inst/t80/q_reg_r, /tb/top_inst/t80/q_reg_sp, /tb/top_inst/t80/q_bus_addr, /tb/top_inst/t80/q_bus_wrdata, /tb/top_inst/t80/reg_bus_a, /tb/top_inst/t80/reg_bus_b, /tb/top_inst/t80/reg_bus_c, /tb/top_inst/t80/reg_wren_h, /tb/top_inst/t80/reg_wren_l, /tb/top_inst/t80/bus_b, /tb/top_inst/t80/bus_a, /tb/top_inst/t80/d_auto_wait, /tb/top_inst/t80/q_alu_op, /tb/top_inst/t80/q_regs_alt, /tb/top_inst/t80/q_memptr, /tb/top_inst/t80/q_instruction, /tb/top_inst/t80/q_prefix, /tb/top_inst/t80/q_reg_bus_a, /tb/top_inst/t80/q_tstate, /tb/top_inst/t80/q_mcycle, /tb/top_inst/t80/q_int_en1, /tb/top_inst/t80/q_int_en2, /tb/top_inst/t80/q_halt, /tb/top_inst/t80/q_xy_state, /tb/top_inst/t80/q_im, /tb/top_inst/t80/q_no_btr, /tb/top_inst/t80/q_btr, /tb/top_inst/t80/q_auto_wait, /tb/top_inst/t80/q_inc_dec_is_zero, /tb/top_inst/t80/q_arith16, /tb/top_inst/t80/q_z16, /tb/top_inst/t80/q_save_alu, /tb/top_inst/t80/q_preserve_c, /tb/top_inst/t80/q_mcycles, /tb/top_inst/t80/q_irq_cycle, /tb/top_inst/t80/q_nmi_cycle, /tb/top_inst/t80/q_read_to_reg, /tb/top_inst/t80/q_xy_ind, /tb/top_inst/t80/incdec16_result, /tb/top_inst/t80/q_di, /tb/top_inst/t80/dec_no_read, /tb/top_inst/t80/t80_wait, /tb/top_inst/t80/d_strobe, /tb/top_inst/t80/q_strobe, /tb/top_inst/t80/cc_is_true, /tb/top_inst/t80/ir_ddd, /tb/top_inst/t80/ir_sss, /tb/top_inst/t80/ir_dpair, /tb/top_inst/t80/dec_arith16, /tb/top_inst/t80/dec_call, /tb/top_inst/t80/dec_exchange_rp, /tb/top_inst/t80/dec_exchange_wh, /tb/top_inst/t80/dec_inc_memptr, /tb/top_inst/t80/dec_inc_pc, /tb/top_inst/t80/dec_iorq, /tb/top_inst/t80/dec_is_bc, /tb/top_inst/t80/dec_is_bt, /tb/top_inst/t80/dec_is_btr, /tb/top_inst/t80/dec_is_ccf, /tb/top_inst/t80/dec_is_cpl, /tb/top_inst/t80/dec_is_di, /tb/top_inst/t80/dec_is_djnz, /tb/top_inst/t80/dec_is_ei, /tb/top_inst/t80/dec_is_ex_af, /tb/top_inst/t80/dec_is_ex_de_hl, /tb/top_inst/t80/dec_is_exx, /tb/top_inst/t80/dec_is_halt, /tb/top_inst/t80/dec_is_inrc, /tb/top_inst/t80/dec_is_jp_ind_hl, /tb/top_inst/t80/dec_is_ldsphl, /tb/top_inst/t80/dec_is_retn, /tb/top_inst/t80/dec_is_rld, /tb/top_inst/t80/dec_is_rrd, /tb/top_inst/t80/dec_is_scf, /tb/top_inst/t80/dec_jump_e, /tb/top_inst/t80/dec_jump, /tb/top_inst/t80/dec_ldw, /tb/top_inst/t80/dec_ldz, /tb/top_inst/t80/dec_no_pc, /tb/top_inst/t80/dec_preserve_c, /tb/top_inst/t80/dec_read_to_acc, /tb/top_inst/t80/dec_read_to_reg, /tb/top_inst/t80/dec_rst_p, /tb/top_inst/t80/dec_save_alu, /tb/top_inst/t80/dec_write, /tb/top_inst/t80/dec_xybit_undoc, /tb/top_inst/t80/dec_im, /tb/top_inst/t80/dec_prefix, /tb/top_inst/t80/dec_set_sw, /tb/top_inst/t80/dec_mcycles, /tb/top_inst/t80/dec_set_addr_to, /tb/top_inst/t80/dec_special_ld, /tb/top_inst/t80/dec_tstates, /tb/top_inst/t80/dec_alu_op, /tb/top_inst/t80/dec_incdec16, /tb/top_inst/t80/dec_set_bus_a_to, /tb/top_inst/t80/dec_set_bus_b_to, /tb/top_inst/t80/alu_bitmask, /tb/top_inst/t80/alu_do_sub, /tb/top_inst/t80/alu_cin, /tb/top_inst/t80/alu_addsub_l, /tb/top_inst/t80/addsub_m, /tb/top_inst/t80/addsub_h, /tb/top_inst/t80/alu_half_carry, /tb/top_inst/t80/alu_carry7, /tb/top_inst/t80/alu_carry, /tb/top_inst/t80/alu_addsub_result, /tb/top_inst/t80/alu_overflow, /tb/top_inst/t80/alu_result, /tb/top_inst/t80/alu_daa_tmp, /tb/top_inst/t80/d_reg_f, /tb/top_inst/t80/really_wait, /tb/top_inst/t80/t_reset, /tb/top_inst/t80/next_is_xy_fetch, /tb/top_inst/t80/save_mux, /tb/top_inst/t80/q_is_rld_rrd, /tb/top_inst/t80/ioq1, /tb/top_inst/t80/ioq2, /tb/top_inst/t80/temp_n, /tb/top_inst/t80/q_reg_idx_a, /tb/top_inst/t80/q_reg_idx_b, /tb/top_inst/t80/q_reg_idx_c, /tb/top_inst/t80/reg_idx_a, /tb/top_inst/t80/reg_idx_b, /tb/top_inst/t80/reg_wrdata, /tb/top_inst/t80/q_nmi, /tb/top_inst/t80/q_nmi_pending, /tb/top_inst/t80/q2_auto_wait, /tb/top_inst/t80/q_pre_xy_f_m }} T80
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/top_inst/cpu_wrdata
add wave -noupdate /tb/top_inst/cpu_rddata
add wave -noupdate /tb/top_inst/clkctrl/dcm_locked
add wave -noupdate /tb/top_inst/clkctrl/clk_locked
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
add wave -noupdate -group SRAM /tb/sram/A
add wave -noupdate -group SRAM /tb/sram/IO
add wave -noupdate -group SRAM /tb/sram/CE_n
add wave -noupdate -group SRAM /tb/sram/OE_n
add wave -noupdate -group SRAM /tb/sram/WE_n
add wave -noupdate -expand -group T80 /tb/top_inst/t80/clk
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reset
add wave -noupdate -expand -group T80 /tb/top_inst/t80/clk_en
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_addr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_wrdata
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_wren
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_iorq
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_strobe
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_rddata
add wave -noupdate -expand -group T80 /tb/top_inst/t80/irq
add wave -noupdate -expand -group T80 /tb/top_inst/t80/irq_vector
add wave -noupdate -expand -group T80 /tb/top_inst/t80/nmi
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_pc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_f
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_a_alt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_f_alt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_i
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_r
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_sp
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_bus_addr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_bus_wrdata
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_bus_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_bus_b
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_bus_c
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_wren_h
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_wren_l
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_b
add wave -noupdate -expand -group T80 /tb/top_inst/t80/bus_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/d_auto_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_alu_op
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_regs_alt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_memptr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_instruction
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_prefix
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_bus_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_tstate
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_mcycle
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_int_en1
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_int_en2
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_halt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_xy_state
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_im
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_no_btr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_btr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_auto_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_inc_dec_is_zero
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_arith16
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_z16
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_save_alu
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_preserve_c
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_mcycles
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_irq_cycle
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_nmi_cycle
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_read_to_reg
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_xy_ind
add wave -noupdate -expand -group T80 /tb/top_inst/t80/incdec16_result
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_di
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_no_read
add wave -noupdate -expand -group T80 /tb/top_inst/t80/t80_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/d_strobe
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_strobe
add wave -noupdate -expand -group T80 /tb/top_inst/t80/cc_is_true
add wave -noupdate -expand -group T80 /tb/top_inst/t80/ir_ddd
add wave -noupdate -expand -group T80 /tb/top_inst/t80/ir_sss
add wave -noupdate -expand -group T80 /tb/top_inst/t80/ir_dpair
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_arith16
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_call
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_exchange_rp
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_exchange_wh
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_inc_memptr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_inc_pc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_iorq
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_bc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_bt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_btr
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_ccf
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_cpl
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_di
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_djnz
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_ei
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_ex_af
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_ex_de_hl
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_exx
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_halt
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_inrc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_jp_ind_hl
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_ldsphl
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_retn
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_rld
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_rrd
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_is_scf
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_jump_e
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_jump
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_ldw
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_ldz
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_no_pc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_preserve_c
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_read_to_acc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_read_to_reg
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_rst_p
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_save_alu
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_write
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_xybit_undoc
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_im
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_prefix
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_set_sw
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_mcycles
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_set_addr_to
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_special_ld
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_tstates
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_alu_op
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_incdec16
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_set_bus_a_to
add wave -noupdate -expand -group T80 /tb/top_inst/t80/dec_set_bus_b_to
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_bitmask
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_do_sub
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_cin
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_addsub_l
add wave -noupdate -expand -group T80 /tb/top_inst/t80/addsub_m
add wave -noupdate -expand -group T80 /tb/top_inst/t80/addsub_h
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_half_carry
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_carry7
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_carry
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_addsub_result
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_overflow
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_result
add wave -noupdate -expand -group T80 /tb/top_inst/t80/alu_daa_tmp
add wave -noupdate -expand -group T80 /tb/top_inst/t80/d_reg_f
add wave -noupdate -expand -group T80 /tb/top_inst/t80/really_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/t_reset
add wave -noupdate -expand -group T80 /tb/top_inst/t80/next_is_xy_fetch
add wave -noupdate -expand -group T80 /tb/top_inst/t80/save_mux
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_is_rld_rrd
add wave -noupdate -expand -group T80 /tb/top_inst/t80/ioq1
add wave -noupdate -expand -group T80 /tb/top_inst/t80/ioq2
add wave -noupdate -expand -group T80 /tb/top_inst/t80/temp_n
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_idx_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_idx_b
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_reg_idx_c
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_idx_a
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_idx_b
add wave -noupdate -expand -group T80 /tb/top_inst/t80/reg_wrdata
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_nmi
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_nmi_pending
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q2_auto_wait
add wave -noupdate -expand -group T80 /tb/top_inst/t80/q_pre_xy_f_m
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1093588436 ps} 0} {{Cursor 2} {89445774 ps} 0}
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
WaveRestoreZoom {88625461 ps} {90266087 ps}
bookmark add wave bookmark0 {{0 ps} {212100032 ps}} 0
