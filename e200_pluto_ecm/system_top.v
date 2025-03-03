// ***************************************************************************
// ***************************************************************************
// Copyright (C) 2014-2023 Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module system_top (
  output          MDIO_PHY_mdc,
  inout           MDIO_PHY_mdio_io,
  input [3:0]     RGMII_rd,
  input           RGMII_rx_ctl,
  input           RGMII_rxc,
  output [3:0]    RGMII_td,
  output          RGMII_tx_ctl,
  output          RGMII_txc,
  output          eth_rst_n ,

  inout   [14:0]  ddr_addr,
  inout   [ 2:0]  ddr_ba,
  inout           ddr_cas_n,
  inout           ddr_ck_n,
  inout           ddr_ck_p,
  inout           ddr_cke,
  inout           ddr_cs_n,
  inout   [ 1:0]  ddr_dm,
  inout   [31:0]  ddr_dq,
  inout   [ 1:0]  ddr_dqs_n,
  inout   [ 1:0]  ddr_dqs_p,
  inout           ddr_odt,
  inout           ddr_ras_n,
  inout           ddr_reset_n,
  inout           ddr_we_n,

  inout           fixed_io_ddr_vrn,
  inout           fixed_io_ddr_vrp,
  inout   [31:0]  fixed_io_mio,
  inout           fixed_io_ps_clk,
  inout           fixed_io_ps_porb,
  inout           fixed_io_ps_srstb,

  input           rx_clk_in,
  input           rx_frame_in,
  input   [11:0]  rx_data_in,
  output          tx_clk_out,
  output          tx_frame_out,
  output  [11:0]  tx_data_out,

  output          enable,
  output          txnrx,

  inout           gpio_resetb,
  inout           gpio_en_agc,
  inout   [ 3:0]  gpio_ctl,
  inout   [ 7:0]  gpio_status,

  output          spi_csn,
  output          spi_clk,
  output          spi_mosi,
  input           spi_miso,


  // clock form vctcxo
  input  wire	 			      CLK_40MHz_FPGA  ,
  // PPS or 10 MHz (need to choose from SW)
  input  wire             PPS_IN          ,
  input  wire             CLKIN_10MHz     ,
  output wire             CLKIN_10MHz_REQ ,

  // Clock disciplining / AD5662 controls
  output wire             CLK_40M_DAC_nSYNC,
  output wire             CLK_40M_DAC_SCLK ,
  output wire             CLK_40M_DAC_DIN ,

  output                  tx_amp_en,

  inout   [7:0]           GPIOB
);

  // internal signals

  wire    [63:0]  gpio_i;
  wire    [63:0]  gpio_o;
  wire    [63:0]  gpio_t;

  wire    [63:0]  w_gpio_o_mod;
  wire    [63:0]  w_gpio_t_mod;
  wire    [3:0]   w_ad9361_ctl;
  wire    [7:0]   w_ad9361_status;

  wire            iic_scl;
  wire            iic_sda;
  wire            phaser_enable;
  wire            pl_burst;
  wire            pl_muxout;
  wire            pl_spi_clk_o;
  wire            pl_spi_miso;
  wire            pl_spi_mosi;
  wire            pl_txdata;

  // instantiations
  assign w_gpio_t_mod[63:12]  = gpio_t[63:12];
  assign w_gpio_t_mod[11:8]   = 4'h0;
  assign w_gpio_t_mod[7:0]    = 8'hFF;

  assign w_gpio_o_mod[63:12]  = gpio_o[63:12];
  assign w_gpio_o_mod[11:8]   = w_ad9361_ctl;
  assign w_gpio_o_mod[7:0]    = 8'h00;

  assign w_ad9361_status      = gpio_i[7:0];

  ad_iobuf #(
    .DATA_WIDTH(14)
  ) i_iobuf (
    .dio_t (w_gpio_t_mod[13:0]),
    .dio_i (w_gpio_o_mod[13:0]),
    .dio_o (gpio_i[13:0]),
    .dio_p ({ gpio_resetb,        // 13:13
              gpio_en_agc,        // 12:12
              gpio_ctl,           // 11: 8
              gpio_status}));     //  7: 0

  assign gpio_i[16:14] = gpio_o[16:14];

  ad_iobuf #(.DATA_WIDTH(8)) gpio_io_buf (
    .dio_t (gpio_t[42:35]),
    .dio_i (gpio_o[42:35]),
    .dio_o (gpio_i[42:35]),
    .dio_p (GPIOB       )
    );

  assign gpio_i[17] = pl_muxout;
  assign phaser_enable = gpio_o[14];


  //PL_GPIO2
  ad_iobuf #(
    .DATA_WIDTH(1)
  ) i_pl_gpio_iobuf (
    .dio_t (phaser_enable),
    .dio_i (pl_spi_clk_o),
    .dio_o (pl_muxout),
    .dio_p (pl_gpio2));

  //PL_GPIO1
  // assign pl_spi_miso = pl_gpio1 & ~phaser_enable;
  // assign pl_burst    = pl_gpio1 &  phaser_enable;

  //PL_GPIO0
  assign pl_gpio0 = phaser_enable ? pl_txdata : pl_spi_mosi;

  assign CLKIN_10MHz_REQ = 1'b1;
  assign eth_rst_n = 1'b1;
  assign tx_amp_en = 1'b1;

  system_wrapper i_system_wrapper (
    .CLKIN_10MHz(CLKIN_10MHz),
    .CLK_40MHz_FPGA(CLK_40MHz_FPGA),
    .CLK_40M_DAC_DIN(CLK_40M_DAC_DIN),
    .CLK_40M_DAC_SCLK(CLK_40M_DAC_SCLK),
    .CLK_40M_DAC_nSYNC(CLK_40M_DAC_nSYNC),
    .PPS_GPS(1'b0),
    .PPS_IN(PPS_IN),
    .PPS_LED(),
    .PPS_LOCKED(),
    .REF_10M_LOCKED(),
    .MDIO_PHY_mdc(MDIO_PHY_mdc),
    .MDIO_PHY_mdio_io(MDIO_PHY_mdio_io),
    .RGMII_rd(RGMII_rd),
    .RGMII_rx_ctl(RGMII_rx_ctl),
    .RGMII_rxc(RGMII_rxc),
    .RGMII_td(RGMII_td),
    .RGMII_tx_ctl(RGMII_tx_ctl),
    .RGMII_txc(RGMII_txc),
    .eth_rst_n(),
    .ddr_addr (ddr_addr),
    .ddr_ba (ddr_ba),
    .ddr_cas_n (ddr_cas_n),
    .ddr_ck_n (ddr_ck_n),
    .ddr_ck_p (ddr_ck_p),
    .ddr_cke (ddr_cke),
    .ddr_cs_n (ddr_cs_n),
    .ddr_dm (ddr_dm),
    .ddr_dq (ddr_dq),
    .ddr_dqs_n (ddr_dqs_n),
    .ddr_dqs_p (ddr_dqs_p),
    .ddr_odt (ddr_odt),
    .ddr_ras_n (ddr_ras_n),
    .ddr_reset_n (ddr_reset_n),
    .ddr_we_n (ddr_we_n),
    .enable (enable),
    .fixed_io_ddr_vrn (fixed_io_ddr_vrn),
    .fixed_io_ddr_vrp (fixed_io_ddr_vrp),
    .fixed_io_mio (fixed_io_mio),
    .fixed_io_ps_clk (fixed_io_ps_clk),
    .fixed_io_ps_porb (fixed_io_ps_porb),
    .fixed_io_ps_srstb (fixed_io_ps_srstb),
    .gpio_i (gpio_i),
    .gpio_o (gpio_o),
    .gpio_t (gpio_t),
    .ad9361_ctl (w_ad9361_ctl),
    .ad9361_status (w_ad9361_status),
    // .iic_main_scl_io (iic_scl),
    // .iic_main_sda_io (iic_sda),
    .rx_clk_in (rx_clk_in),
    .rx_data_in (rx_data_in),
    .rx_frame_in (rx_frame_in),

    .spi0_clk_i (1'b0),
    .spi0_clk_o (spi_clk),
    .spi0_csn_0_o (spi_csn),
    .spi0_csn_1_o (),
    .spi0_csn_2_o (),
    .spi0_csn_i (1'b1),
    .spi0_sdi_i (spi_miso),
    .spi0_sdo_i (1'b0),
    .spi0_sdo_o (spi_mosi),

    // .spi_clk_i(1'b0),
    // .spi_clk_o(pl_spi_clk_o),
    // .spi_csn_i(1'b1),
    // .spi_csn_o(),
    // .spi_sdi_i(pl_spi_miso),
    // .spi_sdo_i(1'b0),
    // .spi_sdo_o(pl_spi_mosi),

    .tdd_ext_sync(pl_burst),
    .txdata_o(pl_txdata),

    .tx_clk_out (tx_clk_out),
    .tx_data_out (tx_data_out),
    .tx_frame_out (tx_frame_out),
    .txnrx (txnrx),
    .up_enable (gpio_o[15]),
    .up_txnrx (gpio_o[16]));

endmodule
