
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
connect_debug_port u_ila_0/clk [get_nets [list i_system_wrapper/system_i/sys_rgmii/U0/i_gmii_to_rgmii_block/gmii_tx_clk ]]
connect_debug_port u_ila_1/clk [get_nets [list i_system_wrapper/system_i/sys_rgmii/U0/i_gmii_to_rgmii_block/system_sys_rgmii_0_core/i_gmii_to_rgmii/gmii_to_rgmii_core_non_versal.i_gmii_to_rgmii/gen_rgmii_rx_clk_zq.bufg_rgmii_rx_clk_0 ]]
set_property port_width 11 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[7]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[8]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[9]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_length[10]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[7]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[8]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[9]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[10]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[11]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[12]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[13]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[14]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[15]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[16]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[17]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[18]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[19]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[20]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[21]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[22]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[23]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[24]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[25]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[26]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[27]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[28]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[29]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[30]} {i_system_wrapper/system_i/udp_intf/U0/w_s_axis_data[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_addr[0]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_addr[1]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_addr[2]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_addr[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_mac_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[7]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[8]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[9]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[10]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[11]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[12]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[13]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[14]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[15]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[16]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[17]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[18]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[19]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[20]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[21]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[22]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[23]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[24]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[25]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[26]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[27]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[28]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[29]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[30]} {i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_data[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_axi_to_udp_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_mac_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_mac_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_mac_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_tx_buffer_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_udp_tx_payload_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_gmii_from_arb_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_s_axis_last ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_s_axis_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_s_axis_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_to_tx_buffer_accepted ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_to_tx_buffer_dropped ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_tx_header_wr_en ]]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[7]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[8]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[9]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[10]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[11]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[12]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[13]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[14]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[15]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[16]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[17]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[18]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[19]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[20]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[21]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[22]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[23]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[24]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[25]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[26]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[27]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[28]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[29]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[30]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_data[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[0]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[1]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[2]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[3]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[4]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[5]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[6]} {i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rxd[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_ready[0]} {i_system_wrapper/system_i/udp_intf/U0/w_m_axis_ready[1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[0]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[1]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[2]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[3]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[4]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[5]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[6]} {i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_data[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_last ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_ready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_from_rx_to_udp_valid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rx_dv ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_Hw_gmii_rx_er ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_m_axis_last ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_m_axis_valid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list i_system_wrapper/system_i/udp_intf/U0/w_rx_to_udp_accepted ]]
create_debug_port u_ila_1 probe

set_property target_constrs_file system_constr.xdc [current_fileset -constrset]
save_constraints -force