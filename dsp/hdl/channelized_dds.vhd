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
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Control_data  : in  dds_control_t;

  Sync_data     : in  channelizer_control_t;

  Output_ctrl   : out channelizer_control_t;
  Output_data   : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
);
end entity channelized_dds;

architecture rtl of channelized_dds is

  type dds_channel_control_t is record
    setup                     : dds_control_setup_entry_t;
    lfsr_control              : dds_control_lfsr_entry_t;
    sin_sweep_control         : dds_control_sin_sweep_entry_t;
    sin_step_control          : dds_control_sin_step_entry_t;
  end record;

  type dds_channel_state_t is record
    lfsr_reg_state            : unsigned(DDS_LFSR_REG_WIDTH - 1 downto 0);
    lfsr_phase_accum          : unsigned(DDS_LFSR_PHASE_ACCUM_WIDTH - 1 downto 0);

    sin_phase_accum           : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    --sin_phase_inc             : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);

    sin_sweep_phase_inc       : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);

    sin_step_cycle            : unsigned(DDS_SIN_STEP_PERIOD_WIDTH - 1 downto 0);
    sin_step_phase_inc        : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
  end record;

  type dds_channel_control_array_t  is array (natural range <>) of dds_channel_control_t;
  type dds_channel_state_array_t    is array (natural range <>) of dds_channel_state_t;

  signal w_rand               : unsigned(31 downto 0);

  signal r_rst                : std_logic;
  signal r_control            : dds_control_t;
  signal w_control_lfsr       : dds_control_lfsr_entry_t;
  signal w_control_sin_sweep  : dds_control_sin_sweep_entry_t;
  signal w_control_sin_step   : dds_control_sin_step_entry_t;

  signal m_channel_control    : dds_channel_control_array_t(NUM_CHANNELS - 1 downto 0);
  signal m_channel_state      : dds_channel_state_array_t(NUM_CHANNELS - 1 downto 0);

  signal r0_sync_data         : channelizer_control_t;

  signal r1_channel_control   : dds_channel_control_t;
  signal r1_channel_state     : dds_channel_state_t;

  signal r2_channel_state     : dds_channel_state_t;
  signal r2_sin_phase_inc     : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst     <= Rst;
      r_control <= Control_data;
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
      r1_channel_control  <= m_channel_control(to_integer(r0_sync_data.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r1_channel_state    <= m_channel_state(to_integer(r0_sync_data.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_channel_state                  <= r1_channel_state;

      r2_channel_state.lfsr_phase_accum <= r1_channel_state.lfsr_phase_accum + r1_channel_control.lfsr_control.lfsr_phase_inc; --TODO: dither
      r2_channel_state.lfsr_reg_state   <= r1_channel_state.lfsr_reg_state; --TODO: LFSR function
      r2_channel_state.sin_phase_accum  <= r1_channel_state.sin_phase_accum + r1_channel_state.sin_phase_inc; --TODO: dither

      if (r1_channel_state.sin_sweep_phase_inc >= r1_channel_control.sin_sweep_phase_inc_stop) then
        r2_channel_state.sin_sweep_phase_inc <= r1_channel_control.sin_sweep_phase_inc_start;
      else
        r2_channel_state.sin_sweep_phase_inc <= r1_channel_state.sin_sweep_phase_inc + r1_channel_control.sin_sweep_phase_inc_step;
      end if;

      if (r1_channel_state.sin_step_cycle = r1_channel_control.sin_step_control.sin_step_period_minus_one) then
        r2_channel_state.sin_step_cycle     <= (others => '0');
        r2_channel_state.sin_step_phase_inc <= r1_channel_control.sin_step_phase_inc_min +
                                               (r1_channel_control.sin_step_phase_inc_rand_offset_mask and w_rand(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0));
      else
        r2_channel_state.sin_step_cycle     <= r1_channel_state.sin_step_cycle + 1;
      end if;

      if (r1_channel_control.dds_sin_phase_inc_select = '0') then
        r2_sin_phase_inc <= r1_channel_state.sin_sweep_phase_inc;
      else
        r2_sin_phase_inc <= r1_channel_state.sin_step_phase_inc;
      end if;
    end if;
  end process;


  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid  <= w_mux_valid;
      Output_data   <= w_mux_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_stretcher_overflow  <= w_stretcher_overflow;
      Error_stretcher_underflow <= w_stretcher_underflow;
      Error_filter_overflow     <= w_filter_overflow;
      Error_mux_input_overflow  <= w_mux_input_overflow;
      Error_mux_fifo_overflow   <= w_mux_fifo_overflow;
      Error_mux_fifo_underflow  <= w_mux_fifo_underflow;
    end if;
  end process;

end architecture rtl;
