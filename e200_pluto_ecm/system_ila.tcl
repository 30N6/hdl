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
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr_next[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 6 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state_reg[5]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_slice_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 6 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/s_state[5]} ]]
create_debug_port u_ila_0 probe
set_property port_width 7 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_words_in_msg[6]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr_next[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_first_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid_pipe[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[channel_index][0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[channel_index][1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[channel_index][2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[channel_index][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[address][14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_mem_rd_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[address][14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[channel_index][0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[channel_index][1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[channel_index][2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[channel_index][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_index[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining_next[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 15 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[11]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[12]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[13]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_last_addr[14]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_outstanding_reads[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[0]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[1]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[2]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[3]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[4]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[5]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[6]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[7]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[8]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[9]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[10]} {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_segment_samples_remaining[11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[channel_last]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[read_valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_req[sync_valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r0_read_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_almost_full ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r1_fifo_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[channel_last]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[read_valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_req[sync_valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r3_read_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_channel_report_pending_any ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_dwell_active ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe39]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_dwell_active_tx ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe40]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_dwell_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe41]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_dwell_start ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe42]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_Error_ext_read_overflow ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe43]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_Error_int_read_overflow ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe44]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_Error_invalid_read ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe45]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_delay ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe46]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_timeout ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe47]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/r_read_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe48]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_read_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe49]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/r_reporter_mem_result_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe50]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/w_fifo_almost_full ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe51]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/i_reporter/w_fifo_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe52]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/g_drfm.i_drfm/w_reporter_mem_read_valid ]]
set_property port_width 3 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_valid[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_ready[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_last ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_ready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_out_valid ]]

set_property target_constrs_file system_constr.xdc [current_fileset -constrset]
save_constraints -force