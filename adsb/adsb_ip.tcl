

source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl
source ../custom_ip_xilinx.tcl

adi_ip_create adsb
custom_ip_files adsb [list \
  {"../common/hdl/common_pkg.vhd"       "common_lib"}   \
  {"../common/hdl/math_pkg.vhd"         "common_lib"}   \
  {"../common/hdl/reset_extender.vhd"   "common_lib"}   \
  {"../axi/hdl/axis_async_fifo.vhd"     "axi_lib"}      \
  {"../dsp/hdl/correlator_simple.vhd"   "dsp_lib"}      \
  {"../dsp/hdl/filter_moving_avg.vhd"   "dsp_lib"}      \
  {"../dsp/hdl/mag_approximation.vhd"   "dsp_lib"}      \
  {"../dsp/hdl/pipeline_delay.vhd"      "dsp_lib"}      \
  {"./hdl/adsb_config.vhd"              "adsb_lib"}     \
  {"./hdl/adsb_demodulator.vhd"         "adsb_lib"}     \
  {"./hdl/adsb_pkg.vhd"                 "adsb_lib"}     \
  {"./hdl/adsb_reporter.vhd"            "adsb_lib"}     \
  {"./hdl/message_sampler.vhd"          "adsb_lib"}     \
  {"./hdl/preamble_detector.vhd"        "adsb_lib"}     \
]

adi_ip_properties_lite adsb
set cc [ipx::current_core]
set_property company_url {https://github.com/30N6}  $cc
set_property display_name "ADS-B demodulator"       $cc
set_property description  "ADS-B demodulator"       $cc

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
adi_add_bus_clock "M_axis_clk" "M_axis" "M_axis_resetn"

ipx::infer_bus_interface Data_clk xilinx.com:signal:clock_rtl:1.0 $cc
set reset_intf      [ipx::infer_bus_interface Data_rst xilinx.com:signal:reset_rtl:1.0 $cc]
set reset_polarity  [ipx::add_bus_parameter "POLARITY" $reset_intf]
set_property value "ACTIVE_HIGH" $reset_polarity

ipx::save_core $cc
