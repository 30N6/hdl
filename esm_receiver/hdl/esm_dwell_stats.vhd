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
  DATA_WIDTH      : natural;
  NUM_CHANNELS    : natural;
  MODULE_ID       : unsigned;
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Enable              : in  std_logic;

  Dwell_active        : in  std_logic;
  Dwell_data          : in  esm_dwell_metadata_t;
  Dwell_sequence_num  : in  unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  Input_ctrl          : out channelizer_control_t;
  Input_data          : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr           : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready          : in  std_logic;
  Axis_valid          : out std_logic;
  Axis_data           : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last           : out std_logic
);
end entity esm_dwell_stats;

architecture rtl of esm_dwell_stats is

  constant POWER_ACCUM_WIDTH    : natural := CHAN_POWER_WIDTH + ESM_DWELL_DURATION_WIDTH;
  constant CHANNEL_INDEX_WIDTH  : natural := clog2(NUM_CHANNELS);
  constant READ_LATENCY         : natural := 2;
  constant READ_PIPE_DEPTH      : natural := READ_LATENCY + 1;

  type state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_DONE,
    S_CLEAR
  );

  signal r_rst                : std_logic;
  signal r_enable             : std_logic;

  signal r_dwell_active       : std_logic;
  signal r_dwell_data         : esm_dwell_metadata_t;
  signal r_dwell_sequence_num : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal r_input_ctrl         : channelizer_control_t;
  signal r_input_data         : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r_input_pwr          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal s_state              : state_t;

  signal m_channel_accum      : unsigned(NUM_CHANNELS - 1 downto 0)(POWER_ACCUM_WIDTH - 1 downto 0);
  signal m_channel_max        : unsigned(NUM_CHANNELS - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_channel_wr_en      : std_logic;
  signal w_channel_wr_index   : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_wr_accum   : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal w_channel_wr_max     : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_channel_rd_index   : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r_read_pipe_active   : std_logic_vector(READ_PIPE_DEPTH - 1 downto 0);
  signal r_read_pipe_ctrl     : channelizer_control_array_t(READ_PIPE_DEPTH - 1 downto 0);
  signal r_read_pipe_pwr      : unsigned_array_t(READ_PIPE_DEPTH - 2 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_channel_rd_accum   : unsigned_array_t(READ_LATENCY - 1 downto 0)(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r_channel_rd_max     : unsigned_array_t(READ_LATENCY - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_channel_new_accum  : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r_channel_new_max    : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r_clear_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal r_read_index         : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r_duration           : unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_timestamp          : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_ts_dwell_start     : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_ts_dwell_end       : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst     <= Rst;
      r_enable  <= Enable;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_ctrl   <= Input_ctrl;
      r_input_data   <= Input_data;
      r_input_pwr    <= Input_pwr;
      r_dwell_active <= Dwell_active;

      if (s_state = S_IDLE) then
        r_dwell_data          <= Dwell_data;
        r_dwell_sequence_num  <= Dwell_sequence_num;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_CLEAR;
      else
        case s_state is
        when S_IDLE =>
          if ((r_enable = '1') and (r_dwell_active = '1') and (r_input_ctrl.valid = '1') and (r_input_ctrl.last = '1')) then
            s_state <= S_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;

        when S_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DONE;
          else
            s_state <= S_ACTIVE;
          end if;

        when S_DONE =>
          s_state <= S_CLEAR;

        when S_CLEAR =>
          if (r_clear_index = (NUM_CHANNELS - 1)) then
            s_state <= S_IDLE;
          else
            s_state <= S_CLEAR;
          end if;

        end case;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_ACTIVE) then
      w_channel_rd_index <= r_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
    else
      --TODO
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_wr_en = '1') then
        m_channel_accum(to_integer(w_channel_wr_index)) <= w_channel_wr_accum;
        m_channel_max(to_integer(w_channel_wr_index))   <= w_channel_wr_max;
      end if;
    end if;
  end process;

  --TODO: read mux

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_rd_accum(0) <= m_channel_accum(to_integer(w_channel_rd_index));
      r_channel_rd_max(0)   <= m_channel_max(to_integer(w_channel_rd_index));

      r_channel_rd_accum(1) <= r_channel_rd_accum(0);
      r_channel_rd_max(1)   <= r_channel_rd_max(0);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_read_pipe_active  <= r_read_pipe_active(READ_PIPE_DEPTH - 2 downto 0) & to_stdlogic(s_state = S_ACTIVE);
      r_read_pipe_ctrl    <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 2 downto 0)   & r_input_ctrl;
      r_read_pipe_pwr     <= r_read_pipe_pwr(READ_PIPE_DEPTH - 3 downto 0)    & r_input_pwr;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_new_accum <= r_channel_rd_accum(1) + r_read_pipe_pwr(1);
      r_channel_new_max   <= r_read_pipe_pwr(1) when (r_read_pipe_pwr(1) > r_channel_rd_max(1)) else r_channel_rd_max(1);
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
    if (s_state = S_CLEAR) then
      w_channel_wr_en     <= '1';
      w_channel_wr_index  <= r_clear_index;
      w_channel_wr_accum  <= (others => '0');
      w_channel_wr_max    <= (others => '0');
    else
      w_channel_wr_en     <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).valid and r_read_pipe_active(READ_PIPE_DEPTH - 1);
      w_channel_wr_index  <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_channel_wr_accum  <= r_channel_new_accum;
      w_channel_wr_max    <= r_channel_new_max;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_timestamp <= (others => '0;);
      else
        r_timestamp <= r_timestamp + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_ts_dwell_start  <= r_timestamp;
        r_duration        <= (others => '0');
      elsif (s_state = S_ACTIVE) then
        r_ts_dwell_end    <= r_timestamp;
        r_duration        <= r_duration + 1;
      end if;
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
