#set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to [get_clocks Clk_x4_adc_clk_mult] 4.000
#set_max_delay -datapath_only -from [get_clocks Clk_x4_adc_clk_mult] -to [get_clocks clk_fpga_0] 4.000
