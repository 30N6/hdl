# Simply change the project settings in this section
# for each new project. There should be no need to
# modify the rest of the script.

set tb_lib      udp_intf_lib
set tb_name     udp_intf_tb
set top_level   $tb_lib.$tb_name

set xilinx_dir  C:/Xilinx/Vivado/2022.2/data/verilog/src

set library_file_list [list \
  glbl [list \
    $xilinx_dir/glbl.v \
  ] \
  common_lib [list \
    ../common/hdl/common_pkg.vhd \
    ] \
  axi_lib [list \
    ../axi/hdl/axis_async_fifo.vhd \
    ../axi/hdl/axis_minififo.vhd \
    ] \
  mem_lib [list \
    ../mem/hdl/xpm_fallthrough_fifo.vhd \
    ../mem/hdl/ram_sdp.vhd \
    ] \
  eth_lib [list \
    ../eth/hdl/eth_pkg.vhd \
    ../eth/hdl/axi_to_udp.vhd \
    ../eth/hdl/ethernet_fcs.vhd \
    ../eth/hdl/gmii_arb.vhd \
    ../eth/hdl/gmii_buffer.vhd \
    ../eth/hdl/mac_1g_tx.vhd \
    ../eth/hdl/mac_rx_to_udp.vhd \
    ../eth/hdl/udp_to_axi.vhd \
    ../eth/hdl/udp_tx.vhd \
    ] \
  udp_intf_lib [list \
    ./hdl/udp_intf.vhd \
    ./sim/udp_intf_tb.sv \
    ] \
]

set incdir_list [list \
  ./sim \
  ./hdl \
  ../common/hdl \
  ../common/sim \
  ../axi/hdl \
  ../mem/hdl \
  ../eth/hdl \
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
        vcom -2008 -mixedsvvh -work $library $file
      } else {
        vlog +define+SIM -sv -mixedsvvh -timescale "1 ns / 1 ns" {*}[split $vlog_lib_str] -work $library $file {*}[split $incdir_str " "]
      }
      set last_compile_time 0
    }
  }
}
set last_compile_time $time_now

# Load the simulation
vsim $top_level glbl.glbl
set NumericStdNoWarnings 1
set BreakOnAssertion 2
run -all

# If waves exists
if [file exist wave.do] {
  source wave.do
}
