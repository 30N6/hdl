source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl
source ../custom_ip_xilinx.tcl

adi_ip_create udp_intf
custom_ip_files udp_intf [list \
  {"../common/hdl/common_pkg.vhd"           "common_lib"}   \
  {"../common/hdl/math_pkg.vhd"             "common_lib"}   \
  {"../axi/hdl/axis_async_fifo.vhd"         "axi_lib"}      \
  {"../axi/hdl/axis_minififo.vhd"           "axi_lib"}      \
  {"../mem/hdl/ram_sdp.vhd"                 "mem_lib"}      \
  {"../mem/hdl/xpm_fallthrough_fifo.vhd"    "mem_lib"}      \
  {"../eth/hdl/eth_pkg.vhd"                 "eth_lib"}      \
  {"../eth/hdl/axi_to_udp.vhd"              "eth_lib"}      \
  {"../eth/hdl/ethernet_fcs.vhd"            "eth_lib"}      \
  {"../eth/hdl/gmii_arb.vhd"                "eth_lib"}      \
  {"../eth/hdl/gmii_buffer.vhd"             "eth_lib"}      \
  {"../eth/hdl/mac_1g_tx.vhd"               "eth_lib"}      \
  {"../eth/hdl/mac_rx_to_udp.vhd"           "eth_lib"}      \
  {"../eth/hdl/udp_to_axi.vhd"              "eth_lib"}      \
  {"../eth/hdl/udp_tx.vhd"                  "eth_lib"}      \
  {"./hdl/udp_intf_pkg.vhd"                 "udp_intf_lib"} \
  {"./hdl/udp_setup.vhd"                    "udp_intf_lib"} \
  {"./hdl/udp_intf.vhd"                     "udp_intf_lib"} \
]

adi_ip_properties_lite udp_intf
set cc [ipx::current_core]
set_property company_url {https://github.com/30N6}  $cc
set_property display_name "UDP-AXI interface"       $cc
set_property description  "UDP-AXI interface"       $cc

adi_add_bus "S_axis" "slave"          \
  "xilinx.com:interface:axis_rtl:1.0" \
  "xilinx.com:interface:axis:1.0"     \
  [list {"S_axis_ready" "TREADY"}     \
        {"S_axis_valid" "TVALID"}     \
        {"S_axis_data"  "TDATA"}      \
        {"S_axis_last"  "TLAST"}      \
  ]
adi_add_bus_clock "S_axis_clk" "S_axis" "S_axis_resetn"

adi_add_bus "M_axis" "master"         \
  "xilinx.com:interface:axis_rtl:1.0" \
  "xilinx.com:interface:axis:1.0"     \
  [list {"m_axis_ready" "TREADY"}     \
        {"M_axis_valid" "TVALID"}     \
        {"M_axis_data" "TDATA"}       \
        {"M_axis_last" "TLAST"}       \
  ]
#no m_axis reset
adi_add_bus_clock "M_axis_clk" "M_axis"

ipx::infer_bus_interface Sys_clk xilinx.com:signal:clock_rtl:1.0 $cc
set reset_intf      [ipx::infer_bus_interface Sys_rst xilinx.com:signal:reset_rtl:1.0 $cc]
set reset_polarity  [ipx::add_bus_parameter "POLARITY" $reset_intf]
set_property value "ACTIVE_HIGH" $reset_polarity

ipx::infer_bus_interface {Hw_gmii_tx_clk Hw_gmii_txd Hw_gmii_tx_en Hw_gmii_tx_er Hw_gmii_crs Hw_gmii_col Hw_gmii_rx_clk Hw_gmii_rxd Hw_gmii_rx_dv Hw_gmii_rx_er} xilinx.com:interface:gmii_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface {Ps_gmii_tx_clk Ps_gmii_txd Ps_gmii_tx_en Ps_gmii_tx_er Ps_gmii_crs Ps_gmii_col Ps_gmii_rx_clk Ps_gmii_rxd Ps_gmii_rx_dv Ps_gmii_rx_er} xilinx.com:interface:gmii_rtl:1.0 [ipx::current_core]

ipx::save_core $cc
