onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_fmsynth/fmsynth/clk
add wave -noupdate /tb_fmsynth/fmsynth/reset
add wave -noupdate /tb_fmsynth/fmsynth/audio_l
add wave -noupdate /tb_fmsynth/fmsynth/audio_r
add wave -noupdate /tb_fmsynth/fmsynth/d_state
add wave -noupdate /tb_fmsynth/fmsynth/q_state
add wave -noupdate -format Analog-Step -height 84 -max 2097151.0 -radix unsigned /tb_fmsynth/fmsynth/d_phase
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_phase
add wave -noupdate /tb_fmsynth/fmsynth/d_lut_idx
add wave -noupdate /tb_fmsynth/fmsynth/q_lut_idx
add wave -noupdate -format Analog-Step -height 100 -max 8190.9999999999991 -radix unsigned /tb_fmsynth/fmsynth/d_val
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_val
add wave -noupdate -format Analog-Step -height 100 -max 4094.9999999999995 -min -4096.0 -radix decimal /tb_fmsynth/fmsynth/d_result
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_result
add wave -noupdate /tb_fmsynth/fmsynth/d_invert
add wave -noupdate /tb_fmsynth/fmsynth/q_invert
add wave -noupdate /tb_fmsynth/fmsynth/d_mute
add wave -noupdate /tb_fmsynth/fmsynth/q_mute
add wave -noupdate /tb_fmsynth/fmsynth/d_waveform
add wave -noupdate /tb_fmsynth/fmsynth/q_waveform
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/d_atten
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_atten
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/d_block
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_block
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/d_fnum
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_fnum
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/d_mult
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/q_mult
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/multiplier
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/fw1
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/phase_inc
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/phase
add wave -noupdate -radix unsigned /tb_fmsynth/fmsynth/lut_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {371180000 ps} 0}
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
