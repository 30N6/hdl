# Simply change the project settings in this section
# for each new project. There should be no need to
# modify the rest of the script.

set tb_lib      ecm_lib
set tb_name     ecm_top_tb
set top_level   $tb_lib.$tb_name

set xilinx_dir  C:/Xilinx/Vivado/2022.2/data/verilog/src

set library_file_list [list \
  glbl [list \
    $xilinx_dir/glbl.v \
  ] \
  common_lib [list \
    ../common/hdl/common_pkg.vhd \
    ../common/hdl/math_pkg.vhd \
    ../common/hdl/reset_extender.vhd \
    ../common/hdl/clk_x4_phase_marker.vhd \
    ../common/hdl/xorshift_32.vhd \
    ../common/sim/math_pkg_sv.sv \
    ] \
  axi_lib [list \
    ../axi/hdl/axis_async_fifo.vhd \
    ../axi/hdl/axis_sync_fifo.vhd \
    ../axi/hdl/axis_mux.vhd \
    ../axi/hdl/axis_minififo.vhd \
    ] \
  clock_lib [list \
    ../clock/hdl/adc_clk_mult_clk_wiz.v \
    ../clock/hdl/adc_clk_mult.v \
    ] \
  mem_lib [list \
    ../mem/hdl/ram_sdp.vhd \
    ../mem/hdl/xpm_fallthrough_fifo.vhd \
    ../mem/hdl/xpm_async_fifo.vhd \
    ] \
  dsp_lib [list \
    ../dsp/hdl/dsp_pkg.vhd \
    ../dsp/hdl/correlator_simple.vhd \
    ../dsp/hdl/filter_moving_avg.vhd \
    ../dsp/hdl/mag_approximation.vhd \
    ../dsp/hdl/pipeline_delay.vhd \
    ../dsp/hdl/fft_sample_fifo.vhd \
    ../dsp/hdl/fft_mux.vhd \
    ../dsp/hdl/fft_4.vhd \
    ../dsp/hdl/fft_4_serializer.vhd \
    ../dsp/hdl/fft_twiddle_mem.vhd \
    ../dsp/hdl/fft_radix2_output.vhd \
    ../dsp/hdl/fft_radix2_stage.vhd \
    ../dsp/hdl/fft_pipelined.vhd \
    ../dsp/hdl/fft_stretcher_2x.vhd \
    ../dsp/hdl/pfb_mux_2x.vhd \
    ../dsp/hdl/pfb_demux_2x.vhd \
    ../dsp/hdl/pfb_baseband_2x.vhd \
    ../dsp/hdl/pfb_filter_buffer.vhd \
    ../dsp/hdl/pfb_filter_mult.vhd \
    ../dsp/hdl/pfb_filter_stage.vhd \
    ../dsp/hdl/pfb_filter.vhd \
    ../dsp/hdl/chan_stretcher_2x.vhd \
    ../dsp/hdl/channelizer_power.vhd \
    ../dsp/hdl/channelizer_common.vhd \
    ../dsp/hdl/channelizer_16.vhd \
    ../dsp/hdl/synthesizer_common.vhd \
    ../dsp/hdl/synthesizer_16.vhd \
    ../dsp/hdl/channelized_dds_lut.vhd \
    ../dsp/hdl/channelized_dds.vhd \
    ] \
  ecm_lib [list \
    ./hdl/ecm_pkg.vhd \
    ./hdl/ecm_config.vhd \
    ./hdl/ecm_dwell_config_decoder.vhd \
    ./hdl/ecm_dwell_trigger.vhd \
    ./hdl/ecm_dwell_tx_engine.vhd \
    ./hdl/ecm_dwell_controller.vhd \
    ./hdl/ecm_dwell_stats_reporter.vhd \
    ./hdl/ecm_dwell_stats.vhd \
    ./hdl/ecm_drfm_reporter.vhd \
    ./hdl/ecm_drfm.vhd \
    ./hdl/ecm_status_reporter.vhd \
    ./hdl/ecm_top.vhd \
    ./sim/ecm_top_tb.sv \
    ] \
]

set incdir_list [list \
  ./sim \
  ./hdl \
  ../common/hdl \
  ../common/sim \
  ../axi/hdl \
  ../clock/hdl \
  ../mem/hdl \
  ../dsp/hdl \
  $xilinx_dir \
]

# After sourcing the script from ModelSim for the
# first time use these commands to recompile.
proc r  {} {
  write format wave -window .main_pane.wave.interior.cs.body.pw.wf wave.do
  uplevel #0 source run_tb.do
}
proc rr {} {global last_compile_time
            set last_compile_time 0
            r                            }
proc q  {} {quit -force                  }

#Does this installation support Tk?
set tk_ok 1
if [catch {package require Tk}] {set tk_ok 0}

# Prefer a fixed point font for the transcript
set PrefMain(font) {Courier 10 roman normal}

# Compile out of date files
set incdir_str_ ""
foreach incdir $incdir_list {
    append incdir_str_ " +incdir+" $incdir
}
set incdir_str [string trim $incdir_str_ " "]

set time_now [clock seconds]
if [catch {set last_compile_time}] {
  set last_compile_time 0
}

set vlog_lib_str ""
foreach {library file_list} $library_file_list {
  append vlog_lib_str " -L " $library
}
set vlog_lib_str [string trim $vlog_lib_str " "]

puts $incdir_str
puts $vlog_lib_str

foreach {library file_list} $library_file_list {
  puts [format "%s   -->  %s" $library $file_list]
  vlib $library
  vmap $library $library

  foreach file $file_list {
    if { $last_compile_time < [file mtime $file] } {
      if [regexp {.vhdl?$} $file] {
        vcom -2008 -mixedsvvh -suppress 12110 -work $library $file
      } else {
        vlog +define+SIM -sv -mixedsvvh -suppress 12110 -timescale "1 ns / 1 ns" {*}[split $vlog_lib_str] -work $library $file {*}[split $incdir_str " "]
      }
      set last_compile_time 0
    }
  }
}
set last_compile_time $time_now

#-L unisim -L unisim_ver

vsim -suppress 12110 $top_level glbl.glbl
set NumericStdNoWarnings 1
set BreakOnAssertion 2
run -all

# If waves exists
if [file exist wave.do] {
  source wave.do
}
