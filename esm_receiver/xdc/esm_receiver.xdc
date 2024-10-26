set_max_delay -from [get_clocks clk_fpga_0]          -to [get_clocks Clk_x4_adc_clk_mult] -datapath_only 4
set_max_delay -from [get_clocks Clk_x4_adc_clk_mult] -to [get_clocks clk_fpga_0]          -datapath_only 4
