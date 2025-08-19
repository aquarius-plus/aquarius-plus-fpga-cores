onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/top_inst/cpu_wr
add wave -noupdate /tb/top_inst/cpu_write
add wave -noupdate /tb/top_inst/cpu_wrdata
add wave -noupdate /tb/top_inst/cpu_rd
add wave -noupdate /tb/top_inst/cpu_read
add wave -noupdate /tb/top_inst/cpu_rddata
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/RESET_n
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/CLK_n
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/CEN
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/WAIT_n
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/INT_n
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/IORQ
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/NoRead
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/Write
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/A
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/DInst
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/DI
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/DO
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/MC
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/TS
add wave -noupdate -expand -group aqp_t80 -expand -group t80 /tb/top_inst/aqp_t80/t80/IntCycle
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/clk
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/reset
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_addr
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wrdata
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_rddata
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/dq_oe
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_memrq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_iorq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_rd
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wr
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/bus_wait
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/irq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_phi
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/phi_rising
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/phi_falling
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_mreq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_read
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/MReq_Inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/Req_Inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/IORQ_t1
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/IORQ_t2
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/IORQ_int
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/IORQ_int_inhibit
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/WR_t2
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_iorq
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_noread
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_write
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_mc
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_ts
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/q_t80_di
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_int_cycle
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_m1_n
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_halt_n
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_inte
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/t80_stop
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/mreq_rw
add wave -noupdate -expand -group aqp_t80 /tb/top_inst/aqp_t80/iorq_rw
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3416140 ps} 0} {{Cursor 2} {639277345 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 309
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
WaveRestoreZoom {0 ps} {13125 ns}
bookmark add wave bookmark0 {{0 ps} {212100032 ps}} 0
