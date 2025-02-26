set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to [get_clocks gmii_clk_125m_out] 4.000
set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to [get_clocks RGMII_rxc]         4.000
#set_max_delay -datapath_only -from [get_clocks gmii_clk_125m_out] -to [get_clocks clk_fpga_0] 4.000
