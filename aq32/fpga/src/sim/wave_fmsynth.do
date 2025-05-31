onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_fmsynth/fmsynth/clk
add wave -noupdate /tb_fmsynth/fmsynth/reset
add wave -noupdate /tb_fmsynth/fmsynth/addr
add wave -noupdate /tb_fmsynth/fmsynth/wrdata
add wave -noupdate /tb_fmsynth/fmsynth/wren
add wave -noupdate /tb_fmsynth/fmsynth/rddata
add wave -noupdate -format Analog-Step -height 50 -max 32767.0 -min -32768.0 -radix decimal /tb_fmsynth/fmsynth/audio_l
add wave -noupdate -format Analog-Step -height 50 -max 32767.0 -min -32768.0 -radix decimal /tb_fmsynth/fmsynth/audio_r
add wave -noupdate -divider {Operator attributes}
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_sel
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_ws
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_am
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_vib
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_egt
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_ksr
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_mult
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_ksl
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_tl
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_ar
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_dr
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_sl
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/op_rr
add wave -noupdate -divider {Channel attributes}
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_sel
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_chb
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_cha
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_fb
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_cnt
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_kon
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_block
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/ch_fnum
add wave -noupdate /tb_fmsynth/fmsynth/op_attr_rddata
add wave -noupdate /tb_fmsynth/fmsynth/ch_attr_rddata
add wave -noupdate -divider State
add wave -noupdate /tb_fmsynth/fmsynth/q_state
add wave -noupdate -format Analog-Step -height 50 -max 2097150.0 -radix unsigned /tb_fmsynth/fmsynth/q_phase
add wave -noupdate -format Analog-Step -height 50 -max 4095.0000000000005 -min -4096.0 -radix decimal /tb_fmsynth/fmsynth/q_result
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_atten
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/multiplier
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/fw1
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/phase_inc
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/phase
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {283509235 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 224
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1050 us}
