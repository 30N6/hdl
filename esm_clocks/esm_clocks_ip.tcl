source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl
source ../custom_ip_xilinx.tcl

adi_ip_create esm_clocks
custom_ip_files esm_clocks [list \
  {"../clock/hdl/adc_clk_mult_clk_wiz.v"    "clock_lib"}        \
  {"../clock/hdl/adc_clk_mult.v"            "clock_lib"}        \
  {"./hdl/esm_clocks.vhd"                   "esm_clocks_lib"}   \
]

adi_ip_properties_lite esm_clocks
set cc [ipx::current_core]
set_property company_url {https://github.com/30N6}  $cc
set_property display_name "ESM clocks"              $cc
set_property description  "ESM clocks"              $cc

ipx::infer_bus_interface Adc_clk xilinx.com:signal:clock_rtl:1.0 $cc
set reset_intf      [ipx::infer_bus_interface Adc_rst xilinx.com:signal:reset_rtl:1.0 $cc]
set reset_polarity  [ipx::add_bus_parameter "POLARITY" $reset_intf]
set_property value "ACTIVE_HIGH" $reset_polarity

ipx::save_core $cc
