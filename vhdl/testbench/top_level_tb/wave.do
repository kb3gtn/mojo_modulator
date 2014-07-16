onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /mojo_top_tb/i_clk50m
add wave -noupdate /mojo_top_tb/i_rst_n
add wave -noupdate /mojo_top_tb/i_serial_rx
add wave -noupdate /mojo_top_tb/o_serial_tx
add wave -noupdate /mojo_top_tb/o_led
add wave -noupdate /mojo_top_tb/o_dac_pin_mode
add wave -noupdate /mojo_top_tb/o_dac_sleep
add wave -noupdate /mojo_top_tb/o_dac_mode
add wave -noupdate /mojo_top_tb/o_dac_cmode
add wave -noupdate /mojo_top_tb/o_dac_clk_p
add wave -noupdate /mojo_top_tb/o_dac_clk_n
add wave -noupdate /mojo_top_tb/o_dac_DB
add wave -noupdate /mojo_top_tb/serial_ce
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg0_addr
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg1_addr
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg2_addr
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg3_addr
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg_working
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_reg_state
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/ftw_update_ff
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/u_cos_nco_1/gen_phase
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/u_cos_nco_1/u_phase_table/ref_phase
add wave -noupdate /mojo_top_tb/uut/u_mojo_modulator/u_cos_nco_1/o_sample
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {500295000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 373
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
WaveRestoreZoom {1291468362 ps} {1599525593 ps}
