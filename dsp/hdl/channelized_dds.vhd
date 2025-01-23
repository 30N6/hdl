library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelized_dds is
generic (
  OUTPUT_DATA_WIDTH   : natural;
  NUM_CHANNELS        : natural;
  CHANNEL_INDEX_WIDTH : natural := clog2(NUM_CHANNELS);
  LATENCY             : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Dwell_active_transmit : in  std_logic;
  Control_data          : in  dds_control_t;
  Sync_data             : in  channelizer_control_t;

  Output_ctrl           : out channelizer_control_t;
  Output_data           : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity channelized_dds;

architecture rtl of channelized_dds is

  constant SIN_LUT_LATENCY            : natural := 3;
  constant DDS_LATENCY                : natural := 7;

  constant POLY_G1                    : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0) := "1000000100";
  constant POLY_G2                    : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0) := "1110100110";
  constant OUTPUT_TAPS_G1             : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0) := "1000000000";
  constant OUTPUT_TAPS_G2             : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0) := "0000100010";

  type dds_channel_control_t is record
    setup                             : dds_control_setup_entry_t;
    lfsr_control                      : dds_control_lfsr_entry_t;
    sin_sweep_control                 : dds_control_sin_sweep_entry_t;
    sin_step_control                  : dds_control_sin_step_entry_t;
  end record;

  type dds_channel_state_t is record
    lfsr_reg_state_g1                 : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0);
    lfsr_reg_state_g2                 : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0);
    lfsr_phase_accum                  : unsigned(DDS_LFSR_PHASE_ACCUM_WIDTH - 1 downto 0);

    sin_phase_accum                   : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_sweep_phase_inc               : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_step_phase_inc                : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_step_cycle                    : unsigned(DDS_SIN_STEP_PERIOD_WIDTH - 1 downto 0);
  end record;

  constant CHANNEL_CONTROL_INIT       : dds_channel_control_t := (setup => (dds_sin_phase_inc_select => '0', dds_output_select => "00"),
                                                                  lfsr_control => (others => (others => '0')),
                                                                  sin_sweep_control => (others => (others => '0')),
                                                                  sin_step_control => (sin_step_phase_inc_min => (others => '0'), others => (others => '0')));
  constant CHANNEL_STATE_INIT         : dds_channel_state_t := (lfsr_reg_state_g1 => (others => '1'), lfsr_reg_state_g2 => (others => '1'), lfsr_phase_accum => (others => '0'),
                                                                sin_phase_accum => (others => '0'), sin_sweep_phase_inc => (others => '0'), sin_step_phase_inc => (others => '0'), sin_step_cycle => (others => '0'));

  type dds_channel_control_array_t    is array (natural range <>) of dds_channel_control_t;
  type dds_channel_state_array_t      is array (natural range <>) of dds_channel_state_t;

  signal w_rand                       : unsigned(31 downto 0);

  signal r_rst                        : std_logic;
  signal r_dwell_active_tx            : std_logic;
  signal r_control                    : dds_control_t;
  signal w_control_lfsr               : dds_control_lfsr_entry_t;
  signal w_control_sin_sweep          : dds_control_sin_sweep_entry_t;
  signal w_control_sin_step           : dds_control_sin_step_entry_t;

  signal m_channel_control            : dds_channel_control_array_t(NUM_CHANNELS - 1 downto 0) := (others => CHANNEL_CONTROL_INIT);
  signal m_channel_state              : dds_channel_state_array_t(NUM_CHANNELS - 1 downto 0) := (others => CHANNEL_STATE_INIT);

  signal r0_sync_data                 : channelizer_control_t;

  signal r1_sync_data                 : channelizer_control_t;
  signal r1_channel_control           : dds_channel_control_t;
  signal r1_channel_state             : dds_channel_state_t;
  signal w1_lfsr_phase_accum_sum      : unsigned(DDS_LFSR_PHASE_ACCUM_WIDTH downto 0);
  signal w1_sin_step_rand_offset      : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 2 downto 0);

  signal r2_sync_data                 : channelizer_control_t;
  signal r2_channel_state             : dds_channel_state_t;
  signal r2_channel_setup             : dds_control_setup_entry_t;
  signal r2_sin_phase_inc             : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
  signal r2_lfsr_toggle               : std_logic;
  signal r2_sin_phase_accum_dithered  : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
  signal w2_sin_lookup_half           : std_logic;
  signal w2_sin_lookup_index          : unsigned(DDS_SIN_LOOKUP_INDEX_WIDTH - 1 downto 0);

  signal r3_sync_data                 : channelizer_control_t;
  signal r3_channel_state             : dds_channel_state_t;
  signal r3_channel_setup             : dds_control_setup_entry_t;
  signal r3_lfsr_output               : std_logic;

  signal r4_sync_data                 : channelizer_control_t;
  signal r4_channel_setup             : dds_control_setup_entry_t;
  signal r4_lfsr_output               : std_logic;

  signal r5_sync_data                 : channelizer_control_t;
  signal r5_channel_setup             : dds_control_setup_entry_t;
  signal r5_lfsr_output               : std_logic;
  signal w5_sin_iq                    : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r6_sync_data                 : channelizer_control_t;
  signal r6_output_data               : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

begin

  assert (LATENCY = DDS_LATENCY)
    report "Unexpected LATENCY value."
    severity failure;

  assert (NUM_CHANNELS >= 8)
    report "NUM_CHANNELS expected to be >= 8, larger than the channel state update delay."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst             <= Rst;
      r_control         <= Control_data;
      r_dwell_active_tx <= Dwell_active_transmit;
    end if;
  end process;

  i_rand : entity common_lib.xorshift_32
  port map (
    Clk     => Clk,
    Rst     => r_rst,

    Output  => w_rand
  );

  w_control_lfsr      <= unpack(r_control.control_data(DDS_CONTROL_LFSR_ENTRY_PACKED_WIDTH - 1 downto 0));
  w_control_sin_sweep <= unpack(r_control.control_data(DDS_CONTROL_SIN_SWEEP_ENTRY_PACKED_WIDTH - 1 downto 0));
  w_control_sin_step  <= unpack(r_control.control_data(DDS_CONTROL_SIN_STEP_ENTRY_PACKED_WIDTH - 1 downto 0));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_control.valid = '1') then
        m_channel_control(to_integer(r_control.channel_index(CHANNEL_INDEX_WIDTH - 1 downto 0))).setup              <= r_control.setup_data;
      end if;
      if ((r_control.valid = '1') and (r_control.control_type = DDS_CONTROL_TYPE_LFSR)) then
        m_channel_control(to_integer(r_control.channel_index(CHANNEL_INDEX_WIDTH - 1 downto 0))).lfsr_control       <= w_control_lfsr;
      end if;
      if ((r_control.valid = '1') and (r_control.control_type = DDS_CONTROL_TYPE_SIN_SWEEP)) then
        m_channel_control(to_integer(r_control.channel_index(CHANNEL_INDEX_WIDTH - 1 downto 0))).sin_sweep_control  <= w_control_sin_sweep;
      end if;
      if ((r_control.valid = '1') and (r_control.control_type = DDS_CONTROL_TYPE_SIN_STEP)) then
        m_channel_control(to_integer(r_control.channel_index(CHANNEL_INDEX_WIDTH - 1 downto 0))).sin_step_control   <= w_control_sin_step;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_sync_data <= Sync_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_sync_data        <= r0_sync_data;
      r1_channel_control  <= m_channel_control(to_integer(r0_sync_data.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r1_channel_state    <= m_channel_state(to_integer(r0_sync_data.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  w1_lfsr_phase_accum_sum <= ('0' & r1_channel_state.lfsr_phase_accum) + ('0' & r1_channel_control.lfsr_control.lfsr_phase_inc);
  w1_sin_step_rand_offset <= r1_channel_control.sin_step_control.sin_step_phase_inc_rand_offset_mask and w_rand(DDS_SIN_PHASE_ACCUM_WIDTH - 2 downto 0);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_sync_data                      <= r1_sync_data;
      r2_channel_state                  <= r1_channel_state;
      r2_channel_setup                  <= r1_channel_control.setup;

      r2_channel_state.lfsr_phase_accum <= w1_lfsr_phase_accum_sum(DDS_LFSR_PHASE_ACCUM_WIDTH - 1 downto 0);
      r2_lfsr_toggle                    <= w1_lfsr_phase_accum_sum(DDS_LFSR_PHASE_ACCUM_WIDTH);

      r2_sin_phase_accum_dithered       <= r1_channel_state.sin_phase_accum + ('0' & w_rand(31));

      if (r1_channel_state.sin_sweep_phase_inc > r1_channel_control.sin_sweep_control.sin_sweep_phase_inc_stop) then
        r2_channel_state.sin_sweep_phase_inc <= r1_channel_control.sin_sweep_control.sin_sweep_phase_inc_start;
      elsif (r1_channel_state.sin_sweep_phase_inc < r1_channel_control.sin_sweep_control.sin_sweep_phase_inc_start) then
        r2_channel_state.sin_sweep_phase_inc <= r1_channel_control.sin_sweep_control.sin_sweep_phase_inc_stop;
      else
        r2_channel_state.sin_sweep_phase_inc <= r1_channel_state.sin_sweep_phase_inc + r1_channel_control.sin_sweep_control.sin_sweep_phase_inc_step;
      end if;

      if (r1_channel_state.sin_step_cycle = r1_channel_control.sin_step_control.sin_step_period_minus_one) then
        r2_channel_state.sin_step_cycle     <= (others => '0');
        r2_channel_state.sin_step_phase_inc <= r1_channel_control.sin_step_control.sin_step_phase_inc_min + signed('0' & w1_sin_step_rand_offset);
      else
        r2_channel_state.sin_step_cycle     <= r1_channel_state.sin_step_cycle + 1;
      end if;

      if (r1_channel_control.setup.dds_sin_phase_inc_select = '0') then
        r2_sin_phase_inc <= r1_channel_state.sin_sweep_phase_inc;
      else
        r2_sin_phase_inc <= r1_channel_state.sin_step_phase_inc;
      end if;
    end if;
  end process;

  w2_sin_lookup_half  <= r2_sin_phase_accum_dithered(DDS_SIN_PHASE_ACCUM_WIDTH - 1);
  w2_sin_lookup_index <= unsigned(r2_sin_phase_accum_dithered(DDS_SIN_PHASE_ACCUM_WIDTH - 2 downto (DDS_SIN_PHASE_ACCUM_WIDTH - 1 - DDS_SIN_LOOKUP_INDEX_WIDTH)));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_sync_data      <= r2_sync_data;
      r3_channel_state  <= r2_channel_state;
      r3_channel_setup  <= r2_channel_setup;

      r3_lfsr_output <= lfsr_output(r2_channel_state.lfsr_reg_state_g1 & r2_channel_state.lfsr_reg_state_g2, OUTPUT_TAPS_G1 & OUTPUT_TAPS_G2);

      r3_channel_state.sin_phase_accum <= r2_channel_state.sin_phase_accum + r2_sin_phase_inc;

      if (r_rst = '1') then
        r3_channel_state.lfsr_reg_state_g1 <= (others => '1');
        r3_channel_state.lfsr_reg_state_g2 <= (others => '1');
      else
        if (r2_lfsr_toggle = '1') then
          r3_channel_state.lfsr_reg_state_g1 <= update_lfsr(r2_channel_state.lfsr_reg_state_g1, POLY_G1);
          r3_channel_state.lfsr_reg_state_g2 <= update_lfsr(r2_channel_state.lfsr_reg_state_g2, POLY_G2);
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r3_sync_data.valid = '1') then
        m_channel_state(to_integer(r3_sync_data.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0))) <= r3_channel_state;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_sync_data      <= r3_sync_data;
      r4_channel_setup  <= r3_channel_setup;
      r4_lfsr_output    <= r3_lfsr_output;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r5_sync_data      <= r4_sync_data;
      r5_channel_setup  <= r4_channel_setup;
      r5_lfsr_output    <= r4_lfsr_output;
    end if;
  end process;

  i_sin_lut : entity dsp_lib.channelized_dds_lut
  generic map (
    DATA_WIDTH => OUTPUT_DATA_WIDTH,
    LATENCY    => SIN_LUT_LATENCY
  )
  port map (
    Clk         => Clk,

    Read_half   => w2_sin_lookup_half,
    Read_index  => w2_sin_lookup_index,

    Read_data   => w5_sin_iq
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r6_sync_data <= r5_sync_data;

      if (r5_channel_setup.dds_output_select = "01") then
        if (r5_lfsr_output = '1') then
          r6_output_data(0) <= to_signed(2**(OUTPUT_DATA_WIDTH-1) - 1, OUTPUT_DATA_WIDTH);
        else
          r6_output_data(0) <= -to_signed(2**(OUTPUT_DATA_WIDTH-1) - 1, OUTPUT_DATA_WIDTH);
        end if;
        r6_output_data(1) <= (others => '0');

      elsif (r5_channel_setup.dds_output_select = "10") then
          r6_output_data(0) <= w5_sin_iq(0);
          r6_output_data(1) <= w5_sin_iq(1);

      elsif (r5_channel_setup.dds_output_select = "11") then
        if (r5_lfsr_output = '1') then
          r6_output_data(0) <= w5_sin_iq(0);
          r6_output_data(1) <= w5_sin_iq(1);
        else
          r6_output_data(0) <= -w5_sin_iq(0);
          r6_output_data(1) <= -w5_sin_iq(1);
        end if;

      else
        r6_output_data <= (others => (others => '0'));
      end if;

      if (r_dwell_active_tx = '0') then
        r6_output_data <= (others => (others => '0'));
      end if;
    end if;
  end process;

  Output_ctrl <= r6_sync_data;
  Output_data <= r6_output_data;

end architecture rtl;
