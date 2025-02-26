# create board design

source $ad_hdl_dir/projects/common/xilinx/adi_fir_filter_bd.tcl
source $ad_hdl_dir/library/axi_tdd/scripts/axi_tdd.tcl
set_property  ip_repo_paths  $ad_hdl_dir/library/ [current_project]
update_ip_catalog

# default ports

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 MDIO_PHY
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:rgmii_rtl:1.0 RGMII

create_bd_port -dir O eth_rst_n

create_bd_port -dir O spi0_csn_2_o
create_bd_port -dir O spi0_csn_1_o
create_bd_port -dir O spi0_csn_0_o
create_bd_port -dir I spi0_csn_i
create_bd_port -dir I spi0_clk_i
create_bd_port -dir O spi0_clk_o
create_bd_port -dir I spi0_sdo_i
create_bd_port -dir O spi0_sdo_o
create_bd_port -dir I spi0_sdi_i

create_bd_port -dir I -from 63 -to 0 gpio_i
create_bd_port -dir O -from 63 -to 0 gpio_o
create_bd_port -dir O -from 63 -to 0 gpio_t

create_bd_port -dir O txdata_o
create_bd_port -dir I tdd_ext_sync


create_bd_port -dir I CLKIN_10MHz
create_bd_port -dir I CLK_40MHz_FPGA
create_bd_port -dir O CLK_40M_DAC_DIN
create_bd_port -dir O CLK_40M_DAC_SCLK
create_bd_port -dir O CLK_40M_DAC_nSYNC
create_bd_port -dir I PPS_GPS
create_bd_port -dir I PPS_IN
create_bd_port -dir O PPS_LED
create_bd_port -dir O PPS_LOCKED
create_bd_port -dir O REF_10M_LOCKED

# instance: sys_ps7

ad_ip_instance processing_system7 sys_ps7

# ps7 settings

ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 3.3V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PACKAGE_NAME clg400
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_ENET0_IO "EMIO"
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_IO "EMIO"
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP0 1
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP1 1
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP2 1
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP3 1
ad_ip_parameter sys_ps7 CONFIG.PCW_EN_CLK1_PORT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_EN_RST1_PORT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100.0
ad_ip_parameter sys_ps7 CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 200.0
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_IO 64
ad_ip_parameter sys_ps7 CONFIG.PCW_SPI1_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_I2C0_I2C0_IO {MIO 10 .. 11}
ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ 50
ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15}
ad_ip_parameter sys_ps7 CONFIG.PCW_I2C1_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SPI0_SPI0_IO EMIO
ad_ip_parameter sys_ps7 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_FABRIC_INTERRUPT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_IO MIO
ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 47}
ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_INTR 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_MODE REVERSE
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_0_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_9_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_10_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_11_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_48_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_49_PULLUP {disabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_53_PULLUP {enabled}

# DDR MT41K256M16 HA-125 (32M, 16bit, 8banks)

ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J256M16 RE-125}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF 0
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 0.048
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 0.050
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 0.241
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 0.240

ad_ip_instance xlconcat sys_concat_intc
ad_ip_parameter sys_concat_intc CONFIG.NUM_PORTS 16

ad_ip_instance proc_sys_reset sys_rstgen
ad_ip_parameter sys_rstgen CONFIG.C_EXT_RST_WIDTH 1

# system reset/clock definitions

# add external ethernet phy
ad_ip_instance gmii_to_rgmii sys_rgmii
ad_ip_parameter sys_rgmii CONFIG.SupportLevel Include_Shared_Logic_in_Core



set axi_vcxo_ctrl [ create_bd_cell -type ip -vlnv user.org:user:axi_vcxo_ctrl:1.0 axi_vcxo_ctrl ]
ad_connect axi_vcxo_ctrl/CLK_40M_DAC_DIN CLK_40M_DAC_DIN
ad_connect axi_vcxo_ctrl/CLK_40M_DAC_SCLK CLK_40M_DAC_SCLK
ad_connect axi_vcxo_ctrl/CLK_40M_DAC_nSYNC CLK_40M_DAC_nSYNC
ad_connect axi_vcxo_ctrl/CLKIN_10MHz CLKIN_10MHz
ad_connect axi_vcxo_ctrl/CLK_40MHz_FPGA CLK_40MHz_FPGA
ad_connect axi_vcxo_ctrl/PPS_GPS PPS_GPS
ad_connect axi_vcxo_ctrl/PPS_IN PPS_IN
ad_connect axi_vcxo_ctrl/PPS_LED PPS_LED
ad_connect axi_vcxo_ctrl/PPS_LOCKED PPS_LOCKED
ad_connect axi_vcxo_ctrl/REF_10M_LOCKED REF_10M_LOCKED




ad_connect  sys_cpu_clk sys_ps7/FCLK_CLK0
ad_connect  sys_200m_clk sys_ps7/FCLK_CLK1
ad_connect  sys_cpu_reset sys_rstgen/peripheral_reset
ad_connect  sys_cpu_resetn sys_rstgen/peripheral_aresetn
ad_connect  eth_rst_n sys_rstgen/peripheral_aresetn
ad_connect  sys_cpu_clk sys_rstgen/slowest_sync_clk
ad_connect  sys_rstgen/ext_reset_in sys_ps7/FCLK_RESET0_N
ad_connect  sys_rgmii/tx_reset sys_rstgen/peripheral_reset
ad_connect  sys_rgmii/rx_reset sys_rstgen/peripheral_reset
ad_connect  sys_rgmii/clkin sys_ps7/FCLK_CLK1
ad_connect  sys_ps7/MDIO_ETHERNET_0 sys_rgmii/MDIO_GEM
ad_connect  sys_rgmii/MDIO_PHY MDIO_PHY
ad_connect  sys_rgmii/RGMII RGMII

# interface connections

ad_connect  ddr sys_ps7/DDR
ad_connect  gpio_i sys_ps7/GPIO_I
ad_connect  gpio_o sys_ps7/GPIO_O
ad_connect  gpio_t sys_ps7/GPIO_T
ad_connect  fixed_io sys_ps7/FIXED_IO

# ps7 spi connections

ad_connect  spi0_csn_2_o sys_ps7/SPI0_SS2_O
ad_connect  spi0_csn_1_o sys_ps7/SPI0_SS1_O
ad_connect  spi0_csn_0_o sys_ps7/SPI0_SS_O
ad_connect  spi0_csn_i sys_ps7/SPI0_SS_I
ad_connect  spi0_clk_i sys_ps7/SPI0_SCLK_I
ad_connect  spi0_clk_o sys_ps7/SPI0_SCLK_O
ad_connect  spi0_sdo_i sys_ps7/SPI0_MOSI_I
ad_connect  spi0_sdo_o sys_ps7/SPI0_MOSI_O
ad_connect  spi0_sdi_i sys_ps7/SPI0_MISO_I


# interrupts

ad_connect  sys_concat_intc/dout sys_ps7/IRQ_F2P
ad_connect  sys_concat_intc/In15 GND
ad_connect  sys_concat_intc/In14 GND
ad_connect  sys_concat_intc/In13 GND
ad_connect  sys_concat_intc/In12 GND
ad_connect  sys_concat_intc/In11 GND
ad_connect  sys_concat_intc/In10 GND
ad_connect  sys_concat_intc/In9 GND
ad_connect  sys_concat_intc/In8 GND
ad_connect  sys_concat_intc/In7 GND
ad_connect  sys_concat_intc/In6 GND
ad_connect  sys_concat_intc/In5 GND
ad_connect  sys_concat_intc/In4 GND
ad_connect  sys_concat_intc/In3 GND
ad_connect  sys_concat_intc/In2 GND
ad_connect  sys_concat_intc/In1 GND
ad_connect  sys_concat_intc/In0 GND


# ad9361

create_bd_port -dir I rx_clk_in
create_bd_port -dir I rx_frame_in
create_bd_port -dir I -from 11 -to 0 rx_data_in

create_bd_port -dir O tx_clk_out
create_bd_port -dir O tx_frame_out
create_bd_port -dir O -from 11 -to 0 tx_data_out

create_bd_port -dir O enable
create_bd_port -dir O txnrx
create_bd_port -dir I up_enable
create_bd_port -dir I up_txnrx

# ad9361 core(s)

ad_ip_instance axi_ad9361 axi_ad9361
ad_ip_parameter axi_ad9361 CONFIG.ID                        0
ad_ip_parameter axi_ad9361 CONFIG.CMOS_OR_LVDS_N            1
ad_ip_parameter axi_ad9361 CONFIG.MODE_1R1T                 1
ad_ip_parameter axi_ad9361 CONFIG.ADC_INIT_DELAY            21
#TODO: IQ correction necessary?
ad_ip_parameter axi_ad9361 CONFIG.DAC_IQCORRECTION_DISABLE  0
ad_ip_parameter axi_ad9361 CONFIG.DAC_DDS_DISABLE           1

ad_ip_instance axi_dmac axi_ad9361_dac_dma
ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_TYPE_SRC 0
ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_TYPE_DEST 1
ad_ip_parameter axi_ad9361_dac_dma CONFIG.CYCLIC 1
ad_ip_parameter axi_ad9361_dac_dma CONFIG.AXI_SLICE_SRC 0
ad_ip_parameter axi_ad9361_dac_dma CONFIG.AXI_SLICE_DEST 0
ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_2D_TRANSFER 0
ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_DATA_WIDTH_DEST 64

ad_ip_instance axi_dmac axi_ad9361_adc_dma
ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_TYPE_SRC 2
ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_TYPE_DEST 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.CYCLIC 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.SYNC_TRANSFER_START 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.AXI_SLICE_SRC 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.AXI_SLICE_DEST 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_2D_TRANSFER 0
ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_DATA_WIDTH_SRC 64
ad_ip_parameter axi_ad9361_adc_dma CONFIG.SYNC_TRANSFER_START {true}

ad_ip_instance axi_dmac axi_custom_dma_d2h
ad_ip_parameter axi_custom_dma_d2h CONFIG.DMA_TYPE_SRC          1
ad_ip_parameter axi_custom_dma_d2h CONFIG.DMA_TYPE_DEST         0
ad_ip_parameter axi_custom_dma_d2h CONFIG.CYCLIC                0
ad_ip_parameter axi_custom_dma_d2h CONFIG.AXI_SLICE_SRC         0
ad_ip_parameter axi_custom_dma_d2h CONFIG.AXI_SLICE_DEST        0
ad_ip_parameter axi_custom_dma_d2h CONFIG.DMA_2D_TRANSFER       0
ad_ip_parameter axi_custom_dma_d2h CONFIG.DMA_DATA_WIDTH_SRC    16
ad_ip_parameter axi_custom_dma_d2h CONFIG.SYNC_TRANSFER_START   0
ad_ip_parameter axi_custom_dma_d2h CONFIG.ENABLE_DIAGNOSTICS_IF 1

ad_ip_instance axi_dmac axi_custom_dma_h2d
ad_ip_parameter axi_custom_dma_h2d CONFIG.DMA_TYPE_SRC          0
ad_ip_parameter axi_custom_dma_h2d CONFIG.DMA_TYPE_DEST         1
ad_ip_parameter axi_custom_dma_h2d CONFIG.CYCLIC                0
ad_ip_parameter axi_custom_dma_h2d CONFIG.AXI_SLICE_SRC         0
ad_ip_parameter axi_custom_dma_h2d CONFIG.AXI_SLICE_DEST        0
ad_ip_parameter axi_custom_dma_h2d CONFIG.DMA_2D_TRANSFER       0
ad_ip_parameter axi_custom_dma_h2d CONFIG.DMA_DATA_WIDTH_DEST   32


ad_add_decimation_filter "rx_fir_decimator" 8 2 1 {61.44} {61.44} \
                         "$ad_hdl_dir/library/util_fir_int/coefile_int.coe"
ad_ip_instance xlslice decim_slice
ad_ip_instance util_cpack2 cpack

# connections

ad_connect  rx_clk_in axi_ad9361/rx_clk_in
ad_connect  rx_frame_in axi_ad9361/rx_frame_in
ad_connect  rx_data_in axi_ad9361/rx_data_in
ad_connect  tx_clk_out axi_ad9361/tx_clk_out
ad_connect  tx_frame_out axi_ad9361/tx_frame_out
ad_connect  tx_data_out axi_ad9361/tx_data_out
ad_connect  enable axi_ad9361/enable
ad_connect  txnrx axi_ad9361/txnrx
ad_connect  up_enable axi_ad9361/up_enable
ad_connect  up_txnrx axi_ad9361/up_txnrx

ad_connect  axi_ad9361/tdd_sync GND
ad_connect  sys_200m_clk axi_ad9361/delay_clk
ad_connect  axi_ad9361/l_clk axi_ad9361/clk

ad_connect axi_ad9361/l_clk rx_fir_decimator/aclk

ad_connect axi_ad9361/adc_valid_i0 rx_fir_decimator/valid_in_0
ad_connect axi_ad9361/adc_enable_i0 rx_fir_decimator/enable_in_0
ad_connect axi_ad9361/adc_data_i0 rx_fir_decimator/data_in_0
ad_connect axi_ad9361/adc_valid_q0 rx_fir_decimator/valid_in_1
ad_connect axi_ad9361/adc_enable_q0 rx_fir_decimator/enable_in_1
ad_connect axi_ad9361/adc_data_q0 rx_fir_decimator/data_in_1

ad_connect axi_ad9361/l_clk cpack/clk
ad_connect axi_ad9361/rst cpack/reset

ad_connect axi_ad9361/adc_enable_i1 cpack/enable_2
ad_connect axi_ad9361/adc_data_i1 cpack/fifo_wr_data_2
ad_connect axi_ad9361/adc_enable_q1 cpack/enable_3
ad_connect axi_ad9361/adc_data_q1 cpack/fifo_wr_data_3

ad_connect cpack/enable_0 rx_fir_decimator/enable_out_0
ad_connect cpack/enable_1 rx_fir_decimator/enable_out_1
ad_connect cpack/fifo_wr_data_0 rx_fir_decimator/data_out_0
ad_connect cpack/fifo_wr_data_1 rx_fir_decimator/data_out_1
ad_connect rx_fir_decimator/valid_out_0 cpack/fifo_wr_en

ad_connect axi_ad9361_adc_dma/fifo_wr cpack/packed_fifo_wr
ad_connect axi_ad9361/up_adc_gpio_out decim_slice/Din
ad_connect rx_fir_decimator/active decim_slice/Dout

ad_connect axi_ad9361/dac_data_i1 GND
ad_connect axi_ad9361/dac_data_q1 GND

ad_connect  axi_ad9361/l_clk axi_ad9361_adc_dma/fifo_wr_clk
ad_connect  axi_ad9361/l_clk axi_ad9361_dac_dma/m_axis_aclk
ad_connect  cpack/fifo_wr_overflow axi_ad9361/adc_dovf

# External TDD
set TDD_CHANNEL_CNT 3
set TDD_DEFAULT_POL 0b010
set TDD_REG_WIDTH 32
set TDD_BURST_WIDTH 32
set TDD_SYNC_WIDTH 0
set TDD_SYNC_INT 0
set TDD_SYNC_EXT 1
set TDD_SYNC_EXT_CDC 1
ad_tdd_gen_create axi_tdd_0 $TDD_CHANNEL_CNT \
                            $TDD_DEFAULT_POL \
                            $TDD_REG_WIDTH \
                            $TDD_BURST_WIDTH \
                            $TDD_SYNC_WIDTH \
                            $TDD_SYNC_INT \
                            $TDD_SYNC_EXT \
                            $TDD_SYNC_EXT_CDC

ad_ip_instance util_vector_logic logic_inv [list \
  C_OPERATION {not} \
  C_SIZE 1]

ad_connect logic_inv/Op1  axi_ad9361/rst
ad_connect logic_inv/Res  axi_tdd_0/resetn
ad_connect axi_ad9361/l_clk axi_tdd_0/clk
ad_connect axi_tdd_0/sync_in tdd_ext_sync
ad_connect axi_tdd_0/tdd_channel_0 txdata_o
ad_connect axi_tdd_0/tdd_channel_1 axi_ad9361_adc_dma/sync

# interconnects

ad_cpu_interconnect 0x79020000 axi_ad9361
ad_cpu_interconnect 0x7C400000 axi_ad9361_adc_dma
ad_cpu_interconnect 0x7C420000 axi_ad9361_dac_dma
ad_cpu_interconnect 0x7C440000 axi_tdd_0
ad_cpu_interconnect 0x7C450000 axi_custom_dma_d2h
ad_cpu_interconnect 0x7C460000 axi_custom_dma_h2d
ad_cpu_interconnect 0x43C00000 axi_vcxo_ctrl

ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP1 {1}
ad_connect sys_cpu_clk sys_ps7/S_AXI_HP1_ACLK
ad_connect axi_ad9361_adc_dma/m_dest_axi sys_ps7/S_AXI_HP1

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
                    [get_bd_addr_spaces axi_ad9361_adc_dma/m_dest_axi] \
                    [get_bd_addr_segs sys_ps7/S_AXI_HP1/HP1_DDR_LOWOCM] \
                    SEG_sys_ps7_HP1_DDR_LOWOCM

ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP2 {1}
ad_connect sys_cpu_clk sys_ps7/S_AXI_HP2_ACLK
ad_connect axi_ad9361_dac_dma/m_src_axi sys_ps7/S_AXI_HP2

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
                    [get_bd_addr_spaces axi_ad9361_dac_dma/m_src_axi] \
                    [get_bd_addr_segs sys_ps7/S_AXI_HP2/HP2_DDR_LOWOCM] \
                    SEG_sys_ps7_HP2_DDR_LOWOCM

# D2H DMA
ad_ip_parameter sys_ps7                       CONFIG.PCW_USE_S_AXI_HP3 {1}
ad_connect      sys_cpu_clk                   sys_ps7/S_AXI_HP3_ACLK
ad_connect      axi_custom_dma_d2h/m_dest_axi sys_ps7/S_AXI_HP3

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
                    [get_bd_addr_spaces axi_custom_dma_d2h/m_dest_axi] \
                    [get_bd_addr_segs sys_ps7/S_AXI_HP3/HP3_DDR_LOWOCM] \
                    SEG_sys_ps7_HP3_DDR_LOWOCM

# H2D DMA
ad_ip_parameter sys_ps7                       CONFIG.PCW_USE_S_AXI_HP0 {1}
ad_connect      sys_cpu_clk                   sys_ps7/S_AXI_HP0_ACLK
ad_connect      axi_custom_dma_h2d/m_src_axi  sys_ps7/S_AXI_HP0

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
                    [get_bd_addr_spaces axi_custom_dma_h2d/m_src_axi] \
                    [get_bd_addr_segs sys_ps7/S_AXI_HP0/HP0_DDR_LOWOCM] \
                    SEG_sys_ps7_HP0_DDR_LOWOCM

ad_connect sys_cpu_clk axi_ad9361_dac_dma/m_src_axi_aclk
ad_connect sys_cpu_clk axi_ad9361_adc_dma/m_dest_axi_aclk
ad_connect sys_cpu_resetn axi_ad9361_adc_dma/m_dest_axi_aresetn
ad_connect sys_cpu_resetn axi_ad9361_dac_dma/m_src_axi_aresetn

ad_connect sys_cpu_clk    axi_custom_dma_d2h/m_dest_axi_aclk
ad_connect sys_cpu_resetn axi_custom_dma_d2h/m_dest_axi_aresetn
ad_connect sys_cpu_clk    axi_custom_dma_h2d/m_src_axi_aclk
ad_connect sys_cpu_resetn axi_custom_dma_h2d/m_src_axi_aresetn
ad_connect sys_cpu_clk    axi_custom_dma_d2h/s_axis_aclk
ad_connect sys_cpu_clk    axi_custom_dma_h2d/m_axis_aclk

# interrupts

ad_cpu_interrupt ps-13 mb-13 axi_ad9361_adc_dma/irq
ad_cpu_interrupt ps-12 mb-12 axi_ad9361_dac_dma/irq

ad_cpu_interrupt ps-9   mb-9    axi_custom_dma_d2h/irq
ad_cpu_interrupt ps-10  mb-10   axi_custom_dma_h2d/irq


# #################

create_bd_port -dir I -from 7 -to 0 ad9361_status
create_bd_port -dir O -from 3 -to 0 ad9361_ctl

ad_ip_instance esm_clocks ecm_clocks
#ad_ip_instance ecm_top    ecm_top
ad_ip_instance udp_intf   udp_intf

#ad_ip_parameter ecm_top   CONFIG.AXI_DATA_WIDTH     32
#ad_ip_parameter ecm_top   CONFIG.ADC_WIDTH          16
#ad_ip_parameter ecm_top   CONFIG.DAC_WIDTH          16
#ad_ip_parameter ecm_top   CONFIG.IQ_WIDTH           12
ad_ip_parameter udp_intf  CONFIG.AXI_DATA_WIDTH     32
ad_ip_parameter udp_intf  CONFIG.OUTPUT_FIFO_DEPTH  1024

ad_connect udp_intf/Sys_clk         sys_cpu_clk
ad_connect udp_intf/Sys_rst         sys_cpu_reset
ad_connect udp_intf/Hw_gmii         sys_rgmii/GMII
ad_connect udp_intf/Ps_gmii         sys_ps7/GMII_ETHERNET_0
ad_connect udp_intf/S_axis_clk      sys_cpu_clk
ad_connect udp_intf/S_axis_resetn   sys_cpu_resetn
ad_connect udp_intf/M_axis_clk      sys_cpu_clk
ad_connect udp_intf/Debug_axis_clk  sys_cpu_clk

ad_connect ecm_clocks/Adc_clk     axi_ad9361/l_clk
ad_connect ecm_clocks/Adc_rst     axi_ad9361/rst

#ad_connect ecm_top/Adc_clk_x4     ecm_clocks/Adc_clk_x4
#ad_connect ecm_top/Adc_clk        axi_ad9361/l_clk
#ad_connect ecm_top/Adc_rst        axi_ad9361/rst
#ad_connect ecm_top/Adc_valid      axi_ad9361/adc_valid_i0
#ad_connect ecm_top/Adc_data_i     axi_ad9361/adc_data_i0
#ad_connect ecm_top/Adc_data_q     axi_ad9361/adc_data_q0
#ad_connect ecm_top/Dac_data_i     axi_ad9361/dac_data_i0
#ad_connect ecm_top/Dac_data_q     axi_ad9361/dac_data_q0
#ad_connect ecm_top/Ad9361_status  ad9361_status
#ad_connect ecm_top/Ad9361_control ad9361_ctl
#
#ad_connect ecm_top/S_axis_clk     sys_cpu_clk
#ad_connect ecm_top/S_axis_resetn  sys_cpu_resetn
#ad_connect ecm_top/M_axis_clk     sys_cpu_clk
#ad_connect ecm_top/M_axis_resetn  sys_cpu_resetn
#ad_connect ecm_top/S_axis         udp_intf/M_axis
#ad_connect ecm_top/M_axis         udp_intf/S_axis

#loopback
ad_connect  axi_ad9361/dac_data_i0  GND
ad_connect  axi_ad9361/dac_data_q0  GND
ad_connect  ad9361_ctl              GND
ad_connect  udp_intf/M_axis         udp_intf/S_axis

ad_connect udp_intf/Debug_axis              axi_custom_dma_d2h/S_axis
ad_connect axi_custom_dma_h2d/m_axis_ready  VCC
