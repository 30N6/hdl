create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 3 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
startgroup 
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0 ]
endgroup
connect_debug_port u_ila_0/clk [get_nets [list i_system_wrapper/system_i/ecm_clocks/U0/i_clocking/inst/Adc_clk_x4 ]]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_transmit_count[4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][4]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][5]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][6]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][7]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][8]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][9]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][10]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][11]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][12]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][13]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][14]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[tag][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[fast_lock_profile][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][0]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][1]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][2]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][3]} {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[next_dwell_index][4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/r_enable_tx ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_Adc_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active_meas ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_active_tx ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_dwell_data[valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_drfm_reports_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_report_enable_drfm ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_report_enable_stats ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_dwell_stats_report_done ]]

set_property target_constrs_file system_constr.xdc [current_fileset -constrset]
save_constraints -force