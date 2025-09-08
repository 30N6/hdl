source ../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set INSERT_ILA 0

adi_project_create e200_pluto_esm 0 {} "xc7z020clg400-2"

adi_project_files e200_pluto_esm [list \
  "system_top.v" \
  "system_constr.xdc" \
  "$ad_hdl_dir/library/hdl/esm_receiver/xdc/esm_receiver.xdc" \
  "$ad_hdl_dir/library/hdl/udp_intf/xdc/udp_intf.xdc" \
  "$ad_hdl_dir/library/common/ad_iobuf.v"]

set_property is_enabled false [get_files  *system_sys_ps7_0.xdc]
adi_project_run e200_pluto_esm
source $ad_hdl_dir/library/axi_ad9361/axi_ad9361_delay.tcl
