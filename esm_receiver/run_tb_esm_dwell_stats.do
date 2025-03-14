# Simply change the project settings in this section
# for each new project. There should be no need to
# modify the rest of the script.

set tb_lib      esm_lib
set tb_name     esm_dwell_stats_tb
set top_level   $tb_lib.$tb_name

set xilinx_dir  C:/Xilinx/Vivado/2022.2/data/verilog/src

set library_file_list [list \
  glbl [list \
    $xilinx_dir/glbl.v \
  ] \
  common_lib [list \
    ../common/hdl/common_pkg.vhd \
    ../common/hdl/math_pkg.vhd \
    ../common/sim/math_pkg_sv.sv \
    ] \
  axi_lib [list \
    ../axi/hdl/axis_async_fifo.vhd \
    ] \
  mem_lib [list \
    ../mem/hdl/ram_sdp.vhd \
    ] \
  dsp_lib [list \
    ../dsp/hdl/dsp_pkg.vhd \
    ] \
  esm_lib [list \
    ./hdl/esm_pkg.vhd \
    ./hdl/esm_dwell_reporter.vhd \
    ./hdl/esm_dwell_stats.vhd \
    ./sim/esm_dwell_stats_tb.sv \
    ] \
]

set incdir_list [list \
  ./sim \
  ./hdl \
  ../common/hdl \
  ../common/sim \
  ../mem/hdl \
  ../axi/hdl \
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

#vsim -suppress 12110 $top_level glbl.glbl   -GNUM_CHANNELS=8
#set NumericStdNoWarnings 1
#set BreakOnAssertion 2
#run -all

vsim -suppress 12110 $top_level glbl.glbl   -GNUM_CHANNELS=64
set NumericStdNoWarnings 1
set BreakOnAssertion 2
run -all


# If waves exists
if [file exist wave.do] {
  source wave.do
}
