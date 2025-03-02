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
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[repeat_count][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[repeat_count][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[repeat_count][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[repeat_count][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 11 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[min_trigger_duration][10]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_pre_lock_delay][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_program_tag[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 28 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][15]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][16]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][17]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][18]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][19]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][20]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][21]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][22]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][23]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][24]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][25]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][26]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[measurement_duration][27]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[frequency][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][0]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][1]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][2]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][3]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][4]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][5]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][6]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[message_type][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][0]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][1]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][2]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][3]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][4]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][5]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][6]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][7]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][8]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][9]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][10]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][11]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][12]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][13]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][14]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][15]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][16]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][17]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][18]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][19]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][20]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][21]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][22]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][23]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][24]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][25]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][26]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][27]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][28]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][29]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][30]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 28 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][15]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][16]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][17]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][18]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][19]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][20]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][21]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][22]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][23]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][24]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][25]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][26]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[total_duration_max][27]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][0]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][1]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][2]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][3]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][4]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][5]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][6]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[module_id][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][0]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][1]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][2]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][3]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][4]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][5]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][6]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][7]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][8]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][9]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][10]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][11]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][12]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][13]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][14]} {i_system_wrapper/system_i/ecm_top/U0/w_module_config[address][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_global_counter[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_ad9361_control[0]} {i_system_wrapper/system_i/ecm_top/U0/w_ad9361_control[1]} {i_system_wrapper/system_i/ecm_top/U0/w_ad9361_control[2]} {i_system_wrapper/system_i/ecm_top/U0/w_ad9361_control[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[pll_post_lock_delay][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/r_combined_rst ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_config_rst ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active_meas ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active_tx ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[global_counter_check]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[global_counter_dec]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[skip_pll_lock_check]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[skip_pll_postlock_wait]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[skip_pll_prelock_wait]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_drfm_reports_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_stats_report_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_enable_chan ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_enable_status ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_enable_synth ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[first]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[last]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_module_config[valid]} ]]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[0]_15[31]} ]]
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
set_property port_width 3 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_last[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[1]_14[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[0]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[1]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[2]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[3]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[4]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[5]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[6]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[7]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[8]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[9]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[10]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[11]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[12]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[13]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[14]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[15]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[16]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[17]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[18]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[19]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[20]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[21]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[22]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[23]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[24]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[25]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[26]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[27]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[28]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[29]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[30]} {i_system_wrapper/system_i/ecm_top/U0/w_d2h_mux_in_data[2]_13[31]} ]]
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