source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl
source ../custom_ip_xilinx.tcl

adi_ip_create ecm_receiver
custom_ip_files ecm_receiver [list \
  {"../common/hdl/common_pkg.vhd"           "common_lib"}   \
  {"../common/hdl/math_pkg.vhd"             "common_lib"}   \
  {"../common/hdl/reset_extender.vhd"       "common_lib"}   \
  {"../common/hdl/clk_x4_phase_marker.vhd"  "common_lib"}   \
  {"../common/hdl/xorshift_32.vhd"          "common_lib"}   \
  {"../axi/hdl/axis_async_fifo.vhd"         "axi_lib"}      \
  {"../axi/hdl/axis_sync_fifo.vhd"          "axi_lib"}      \
  {"../axi/hdl/axis_mux.vhd"                "axi_lib"}      \
  {"../axi/hdl/axis_minififo.vhd"           "axi_lib"}      \
  {"../mem/hdl/ram_sdp.vhd"                 "mem_lib"}      \
  {"../mem/hdl/xpm_fallthrough_fifo.vhd"    "mem_lib"}      \
  {"../mem/hdl/xpm_async_fifo.vhd"          "mem_lib"}      \
  {"../dsp/hdl/dsp_pkg.vhd"                 "dsp_lib"}      \
  {"../dsp/hdl/correlator_simple.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/filter_moving_avg.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/mag_approximation.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/pipeline_delay.vhd"          "dsp_lib"}      \
  {"../dsp/hdl/fft_mux.vhd"                 "dsp_lib"}      \
  {"../dsp/hdl/fft_sample_fifo.vhd"         "dsp_lib"}      \
  {"../dsp/hdl/fft_4.vhd"                   "dsp_lib"}      \
  {"../dsp/hdl/fft_4_serializer.vhd"        "dsp_lib"}      \
  {"../dsp/hdl/fft_pipelined.vhd"           "dsp_lib"}      \
  {"../dsp/hdl/fft_radix2_stage.vhd"        "dsp_lib"}      \
  {"../dsp/hdl/fft_twiddle_mem.vhd"         "dsp_lib"}      \
  {"../dsp/hdl/fft_radix2_output.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/fft_stretcher_2x.vhd"        "dsp_lib"}      \
  {"../dsp/hdl/pfb_mux_2x.vhd"              "dsp_lib"}      \
  {"../dsp/hdl/pfb_demux_2x.vhd"            "dsp_lib"}      \
  {"../dsp/hdl/pfb_baseband_2x.vhd"         "dsp_lib"}      \
  {"../dsp/hdl/pfb_filter.vhd"              "dsp_lib"}      \
  {"../dsp/hdl/pfb_filter_buffer.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/pfb_filter_mult.vhd"         "dsp_lib"}      \
  {"../dsp/hdl/pfb_filter_stage.vhd"        "dsp_lib"}      \
  {"../dsp/hdl/chan_stretcher_2x.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/channelizer_power.vhd"       "dsp_lib"}      \
  {"../dsp/hdl/channelizer_common.vhd"      "dsp_lib"}      \
  {"../dsp/hdl/channelizer_16.vhd"          "dsp_lib"}      \
  {"../dsp/hdl/synthesizer_common.vhd"      "dsp_lib"}      \
  {"../dsp/hdl/synthesizer_16.vhd"          "dsp_lib"}      \
  {"../dsp/hdl/channelized_dds_lut.vhd"     "dsp_lib"}      \
  {"../dsp/hdl/channelized_dds.vhd"         "dsp_lib"}      \
  {"./hdl/ecm_pkg.vhd"                      "ecm_lib"}      \
  {"./hdl/ecm_config.vhd"                   "ecm_lib"}      \
  {"./hdl/ecm_dwell_config_decoder.vhd"     "ecm_lib"}      \
  {"./hdl/ecm_dwell_trigger.vhd"            "ecm_lib"}      \
  {"./hdl/ecm_dwell_tx_engine.vhd"          "ecm_lib"}      \
  {"./hdl/ecm_dwell_controller.vhd"         "ecm_lib"}      \
  {"./hdl/ecm_dwell_stats_reporter.vhd"     "ecm_lib"}      \
  {"./hdl/ecm_dwell_stats.vhd"              "ecm_lib"}      \
  {"./hdl/ecm_drfm_reporter.vhd"            "ecm_lib"}      \
  {"./hdl/ecm_drfm.vhd"                     "ecm_lib"}      \
  {"./hdl/ecm_output_block.vhd"             "ecm_lib"}      \
  {"./hdl/ecm_sync_block.vhd"               "ecm_lib"}      \
  {"./hdl/ecm_status_reporter.vhd"          "ecm_lib"}      \
  {"./hdl/ecm_top.vhd"                      "ecm_lib"}      \
]

adi_ip_properties_lite ecm_top
set cc [ipx::current_core]
set_property company_url {https://github.com/30N6}  $cc
set_property display_name "ECM top level"           $cc
set_property description  "ECM top level"           $cc

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

ipx::infer_bus_interface Adc_clk xilinx.com:signal:clock_rtl:1.0 $cc
set reset_intf      [ipx::infer_bus_interface Adc_rst xilinx.com:signal:reset_rtl:1.0 $cc]
set reset_polarity  [ipx::add_bus_parameter "POLARITY" $reset_intf]
set_property value "ACTIVE_HIGH" $reset_polarity

ipx::save_core $cc
