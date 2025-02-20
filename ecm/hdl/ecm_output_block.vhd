library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity ecm_output_block is
generic (
  ENABLE_DDS  : boolean;
  ENABLE_DRFM : boolean
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Dwell_active_transmit : in  std_logic;
  Dwell_transmit_count  : in unsigned(ECM_CHANNEL_COUNT_WIDTH - 1 downto 0);
  Output_control        : in  ecm_output_control_t;

  Dds_ctrl              : in  channelizer_control_t;
  Dds_data              : in  signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);

  Drfm_ctrl             : in  channelizer_control_t;
  Drfm_data             : in  signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  Synthesizer_ctrl      : out synthesizer_control_t;
  Synthesizer_data      : out signed_array_t(1 downto 0)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);

  Error_dds_drfm_sync   : out std_logic
);
end entity ecm_output_block;

architecture rtl of ecm_output_block is

  constant PRODUCT_WIDTH    : natural := ECM_DDS_DATA_WIDTH + ECM_DRFM_DATA_WIDTH;

  signal r_rst                    : std_logic;
  signal r_dwell_active_transmit  : std_logic;
  signal r_dwell_transmit_count   : unsigned(ECM_CHANNEL_COUNT_WIDTH - 1 downto 0);
  signal r_output_control         : ecm_output_control_t;
  signal r_clear_index            : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal w_output_control         : ecm_output_control_t;
  signal m_output_control         : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_TX_OUTPUT_CONTROL_WIDTH - 1 downto 0);

  signal r0_dds_ctrl              : channelizer_control_t;
  signal r0_dds_data              : signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);
  signal r0_drfm_ctrl             : channelizer_control_t;
  signal r0_drfm_data             : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal r1_dds_ctrl              : channelizer_control_t;
  signal r1_dds_data              : signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);
  signal r1_drfm_ctrl             : channelizer_control_t;
  signal r1_drfm_data             : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal r2_shared_ctrl           : channelizer_control_t;
  signal r2_dds_data              : signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);
  signal r2_drfm_data             : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);
  signal r2_mult_ac               : signed(PRODUCT_WIDTH - 1 downto 0);
  signal r2_mult_bd               : signed(PRODUCT_WIDTH - 1 downto 0);
  signal r2_mult_ad               : signed(PRODUCT_WIDTH - 1 downto 0);
  signal r2_mult_bc               : signed(PRODUCT_WIDTH - 1 downto 0);

  signal r3_shared_ctrl           : channelizer_control_t;
  signal r3_dds_data              : signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);
  signal r3_drfm_data             : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);
  signal r3_product_data          : signed_array_t(1 downto 0)(PRODUCT_WIDTH downto 0);
  signal r3_output_control        : unsigned(ECM_TX_OUTPUT_CONTROL_WIDTH - 1 downto 0);

  signal r4_output_ctrl           : synthesizer_control_t;
  signal r4_output_data           : signed_array_t(1 downto 0)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);

begin

  assert (ENABLE_DDS or ENABLE_DRFM)
    report "DDS or DRFM must be enabled."
    severity failure;

  assert (ECM_DDS_DATA_WIDTH >= ECM_SYNTHESIZER_DATA_WIDTH)
    report "ECM_DDS_DATA_WIDTH expected to be >= ECM_SYNTHESIZER_DATA_WIDTH"
    severity failure;

  assert (ECM_DRFM_DATA_WIDTH >= ECM_SYNTHESIZER_DATA_WIDTH)
    report "ECM_DRFM_DATA_WIDTH expected to be >= ECM_SYNTHESIZER_DATA_WIDTH"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst                   <= Rst;
      r_dwell_active_transmit <= Dwell_active_transmit;
      r_dwell_transmit_count  <= Dwell_transmit_count;
      r_output_control        <= Output_control;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_clear_index <= r_clear_index + 1;
    end if;
  end process;

  process(all)
  begin
    if (r_rst = '1') then
      w_output_control.valid          <= '1';
      w_output_control.channel_index  <= r_clear_index;
      w_output_control.control        <= to_unsigned(ECM_TX_OUTPUT_CONTROL_DISABLED, ECM_TX_OUTPUT_CONTROL_WIDTH);
    else
      w_output_control                <= r_output_control;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_output_control.valid = '1') then
        m_output_control(to_integer(w_output_control.channel_index)) <= w_output_control.control;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_dds_ctrl   <= Dds_ctrl;
      r0_dds_data   <= Dds_data;
      r0_drfm_ctrl  <= Drfm_ctrl;
      r0_drfm_data  <= Drfm_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_dds_ctrl   <= r0_dds_ctrl;
      r1_dds_data   <= r0_dds_data;
      r1_drfm_ctrl  <= r0_drfm_ctrl;
      r1_drfm_data  <= r0_drfm_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (ENABLE_DDS) then
        r2_shared_ctrl  <= r1_dds_ctrl;
      else
        r2_shared_ctrl  <= r1_drfm_ctrl;
      end if;

      r2_dds_data       <= r1_dds_data;
      r2_drfm_data      <= r1_drfm_data;
      r2_mult_ac        <= r1_dds_data(0) * r1_drfm_data(0);
      r2_mult_bd        <= r1_dds_data(1) * r1_drfm_data(1);
      r2_mult_ad        <= r1_dds_data(0) * r1_drfm_data(1);
      r2_mult_bc        <= r1_dds_data(1) * r1_drfm_data(0);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_shared_ctrl      <= r2_shared_ctrl;
      r3_dds_data         <= r2_dds_data;
      r3_drfm_data        <= r2_drfm_data;
      r3_product_data(0)  <= resize_up(r2_mult_ac, PRODUCT_WIDTH + 1) - resize_up(r2_mult_bd, PRODUCT_WIDTH + 1);
      r3_product_data(1)  <= resize_up(r2_mult_ad, PRODUCT_WIDTH + 1) + resize_up(r2_mult_bc, PRODUCT_WIDTH + 1);
      r3_output_control   <= m_output_control(to_integer(r2_shared_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_output_ctrl.valid                <= r3_shared_ctrl.valid;
      r4_output_ctrl.last                 <= r3_shared_ctrl.last;
      r4_output_ctrl.data_index           <= r3_shared_ctrl.data_index;
      r4_output_ctrl.transmit_active      <= r_dwell_active_transmit;
      r4_output_ctrl.active_channel_count <= resize_up(r_dwell_transmit_count, SYNTHESIZER_CHANNEL_COUNT_WIDTH);

      if (r_dwell_active_transmit = '0') then
        r4_output_data <= (others => (others => '0'));
      elsif (r3_output_control = ECM_TX_OUTPUT_CONTROL_DDS) then
        r4_output_data(0) <= r3_dds_data(0)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);
        r4_output_data(1) <= r3_dds_data(1)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);
      elsif (r3_output_control = ECM_TX_OUTPUT_CONTROL_DRFM) then
        r4_output_data(0) <= r3_drfm_data(0)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);
        r4_output_data(1) <= r3_drfm_data(1)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);
      elsif (r3_output_control = ECM_TX_OUTPUT_CONTROL_MIXER) then
        r4_output_data(0) <= r3_product_data(0)(PRODUCT_WIDTH downto (PRODUCT_WIDTH - ECM_SYNTHESIZER_DATA_WIDTH + 1));
        r4_output_data(1) <= r3_product_data(1)(PRODUCT_WIDTH downto (PRODUCT_WIDTH - ECM_SYNTHESIZER_DATA_WIDTH + 1));
      else
        r4_output_data <= (others => (others => '0'));
      end if;
    end if;
  end process;

  Synthesizer_ctrl  <= r4_output_ctrl;
  Synthesizer_data  <= r4_output_data;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (ENABLE_DDS and ENABLE_DRFM) then
        Error_dds_drfm_sync <= r1_dds_ctrl.valid and r1_drfm_ctrl.valid and to_stdlogic((r1_dds_ctrl.valid       /= r1_drfm_ctrl.valid) or
                                                                                        (r1_dds_ctrl.last        /= r1_drfm_ctrl.last) or
                                                                                        (r1_dds_ctrl.data_index  /= r1_drfm_ctrl.data_index));
      else
        Error_dds_drfm_sync <= '0';
      end if;
    end if;
  end process;

end architecture rtl;
