library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_dwell_stats is
generic (
  AXI_DATA_WIDTH  : natural;
  DATA_WIDTH      : natural
);
port (
  Adc_clk       : in  std_logic;
  Adc_rst       : in  std_logic;

  Enable        : in  std_logic;

  Dwell_active  : in  std_logic;
  Dwell_data    : in  esm_dwell_metadata_t;

  Input_ctrl    : out channelizer_control_t;
  Input_data    : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Axis_ready    : in  std_logic;
  Axis_valid    : out std_logic;
  Axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last     : out std_logic
);
end entity esm_dwell_stats;

architecture rtl of esm_dwell_stats is


begin



  process(data_clk)
  begin
    if rising_edge(data_clk) then
      r_combined_rst <= Adc_rst or w_config_rst;
    end if;
  end process;


  i_master_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => data_clk,
    S_axis_resetn   => not(r_combined_rst),
    S_axis_ready    => w_reporter_axis_ready,
    S_axis_valid    => w_reporter_axis_valid,
    S_axis_data     => w_reporter_axis_data,
    S_axis_last     => w_reporter_axis_last,

    M_axis_clk      => M_axis_clk,
    M_axis_ready    => M_axis_ready,
    M_axis_valid    => M_axis_valid,
    M_axis_data     => M_axis_data,
    M_axis_last     => M_axis_last
  );

  i_slave_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => S_axis_clk,
    S_axis_resetn   => S_axis_resetn,
    S_axis_ready    => S_axis_ready,
    S_axis_valid    => S_axis_valid,
    S_axis_data     => S_axis_data,
    S_axis_last     => S_axis_last,

    M_axis_clk      => data_clk,
    M_axis_ready    => w_config_axis_ready,
    M_axis_valid    => w_config_axis_valid,
    M_axis_data     => w_config_axis_data,
    M_axis_last     => w_config_axis_last
  );

  w_reporter_axis_valid <= r_test; --TODO
  w_reporter_axis_data  <= (others => '0');
  w_reporter_axis_last  <= '1';
  --w_config_axis_ready   <= ; --TODO --'1';

end architecture rtl;
