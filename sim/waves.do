# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {Top-level signals}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave UUT/top_state
add wave -uns UUT/UART_timer

add wave -divider -height 10 {SRAM signals}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -bin UUT/SRAM_we_n
add wave -hex UUT/SRAM_read_data

#add wave -divider -height 10 {YUV to RGB signals}
#add wave UUT/YUVtoRGB_unit/state
#add wave -uns UUT/YUVtoRGB_unit/pixel_pair_count
#add wave -uns UUT/YUVtoRGB_unit/per_row_count
#add wave -uns UUT/YUVtoRGB_unit/rgb_write_count
#add wave -hex UUT/YUVtoRGB_unit/R
#add wave -hex UUT/YUVtoRGB_unit/G
#add wave -hex UUT/YUVtoRGB_unit/B
#add wave -hex UUT/YUVtoRGB_unit/red_write
#add wave -hex UUT/YUVtoRGB_unit/green_write
#add wave -hex UUT/YUVtoRGB_unit/blue_write
#add wave -hex UUT/YUVtoRGB_unit/Y
#add wave -hex UUT/YUVtoRGB_unit/U
#add wave -hex UUT/YUVtoRGB_unit/V
#add wave -hex UUT/YUVtoRGB_unit/U_prime
#add wave -hex UUT/YUVtoRGB_unit/V_prime
#add wave -hex UUT/YUVtoRGB_unit/U_inter_data
#add wave -hex UUT/YUVtoRGB_unit/V_inter_data

add wave -divider -height 10 {S Conversion signals}
add wave UUT/S_Conversion_unit/top_state
add wave UUT/S_Conversion_unit/l_fetch_state
add wave UUT/S_Conversion_unit/l_t_state
add wave UUT/S_Conversion_unit/fetch_state
add wave UUT/S_Conversion_unit/t_state
add wave UUT/S_Conversion_unit/s_state
add wave UUT/S_Conversion_unit/write_state
add wave UUT/S_Conversion_unit/e_s_state
add wave UUT/S_Conversion_unit/e_write_state
add wave UUT/S_Conversion_unit/S_enable

add wave -uns UUT/S_Conversion_unit/data_count_long
add wave -uns UUT/S_Conversion_unit/data_count

add wave -s UUT/S_Conversion_unit/Tmac
add wave -s UUT/S_Conversion_unit/Smac_1
add wave -s UUT/S_Conversion_unit/Smac_2
add wave -s UUT/S_Conversion_unit/Smac_3

add wave -uns UUT/S_Conversion_unit/cols

add wave -uns UUT/S_Conversion_unit/address_a
add wave -uns UUT/S_Conversion_unit/address_b
add wave -s UUT/S_Conversion_unit/write_data_b
add wave -s UUT/S_Conversion_unit/write_data_a


add wave -s UUT/S_Conversion_unit/M1_result
add wave -s UUT/S_Conversion_unit/M2_result
add wave -s UUT/S_Conversion_unit/M3_result
add wave -s UUT/S_Conversion_unit/M1_op_1
add wave -s UUT/S_Conversion_unit/M1_op_2
add wave -s UUT/S_Conversion_unit/M2_op_1
add wave -s UUT/S_Conversion_unit/M2_op_2
add wave -s UUT/S_Conversion_unit/M3_op_1
add wave -s UUT/S_Conversion_unit/M3_op_2

#add wave -divider -height 10 {VGA signals}
#add wave -bin UUT/VGA_unit/VGA_HSYNC_O
#add wave -bin UUT/VGA_unit/VGA_VSYNC_O
#add wave -uns UUT/VGA_unit/pixel_X_pos
#add wave -uns UUT/VGA_unit/pixel_Y_pos
#add wave -hex UUT/VGA_unit/VGA_red
#add wave -hex UUT/VGA_unit/VGA_green
#add wave -hex UUT/VGA_unit/VGA_blue