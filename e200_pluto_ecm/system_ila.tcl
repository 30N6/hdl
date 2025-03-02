create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
create_debug_core u_ila_1 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
connect_debug_port u_ila_0/clk [get_nets [list i_system_wrapper/system_i/ecm_clocks/U0/i_clocking/inst/Adc_clk_x4 ]]
connect_debug_port u_ila_1/clk [get_nets [list i_system_wrapper/system_i/sys_ps7/inst/FCLK_CLK0 ]]
set_property port_width 6 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[5]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[5]} ]]
create_debug_port u_ila_0 probe
set_property port_width 7 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[6]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[14]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[15]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[16]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[17]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[18]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[19]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[20]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[21]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[22]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[23]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[24]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[25]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[26]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[27]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[28]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[29]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[30]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_data[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_almost_full ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_report_pending_any ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_delay ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/w_fifo_almost_full ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/w_fifo_ready ]]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_6[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_data[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_8[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_7[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_last ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_ready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_valid ]]

set_property target_constrs_file system_constr.xdc [current_fileset -constrset]
save_constraints -force