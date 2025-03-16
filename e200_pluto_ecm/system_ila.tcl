create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list i_system_wrapper/system_i/axi_ad9361/inst/i_dev_if/i_clk/clk ]]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_i[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_status[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_i[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Dac_data_q[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[3]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[4]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[5]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[6]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[7]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[8]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[9]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[10]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[11]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[12]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[13]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[14]} {i_system_wrapper/system_i/ecm_top/U0/w_Adc_data_q[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[0]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[1]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[2]} {i_system_wrapper/system_i/ecm_top/U0/w_Ad9361_control_o[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list i_system_wrapper/system_i/ecm_top/U0/w_Adc_valid ]]

set_property target_constrs_file system_constr.xdc [current_fileset -constrset]
save_constraints -force