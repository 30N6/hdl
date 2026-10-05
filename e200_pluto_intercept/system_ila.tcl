create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 4 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list i_system_wrapper/system_i/esm_clocks/U0/i_clocking/inst/Adc_clk_x4 ]]
set_property port_width 3 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_ready[0]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_ready[1]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_ready[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_valid[0]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_valid[1]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_valid[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_index[0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_index[1]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_index[2]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_index[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_last[0]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_last[1]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_last[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[0]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[1]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[2]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[3]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[4]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[5]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[6]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[7]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[8]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[9]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[10]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[11]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[12]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[13]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[14]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[15]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[16]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[17]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[18]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[19]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[20]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[21]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[22]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[23]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[24]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[25]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[26]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[27]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[28]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[29]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[30]} {i_system_wrapper/system_i/int_top/U0/w_d2h_fifo_in_data[1]_22[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[state][0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[state][1]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[trigger_type][0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[trigger_type][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][1]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][2]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][3]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][4]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][5]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][6]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][7]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[channel_index][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[stream_index][0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[stream_index][1]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[stream_index][2]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context[stream_index][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[stream_index][0]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[stream_index][1]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[stream_index][2]} {i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_data[stream_index][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r3_context_wr_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_output_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/r4_stream_release_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_fifo_empty ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_fifo_overflow ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_fifo_rd_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_fifo_underflow ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_stream_encoder_errors[fifo_overflow]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_stream_encoder_errors[fifo_underflow]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_stream_encoder_errors[reporter_overflow]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {i_system_wrapper/system_i/int_top/U0/w_stream_encoder_errors[reporter_timeout]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_req ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_ack ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list i_system_wrapper/system_i/int_top/U0/i_stream_encoder/w_stream_slot_valid ]]
