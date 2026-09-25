library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_stream_encoder is
generic (
  AXI_DATA_WIDTH  : natural;
  DATA_WIDTH      : natural
);
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Enable                  : in  std_logic;
  Module_config           : in  intercept_config_data_t;

  Dwell_data              : in  intercept_dwell_data_t;
  Dwell_active            : in  std_logic;

  Input_ctrl              : in  channelizer_control_t;
  Input_data              : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr               : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready              : in  std_logic;
  Axis_valid              : out std_logic;
  Axis_data               : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last               : out std_logic;

  Error_fifo_overflow     : out std_logic;
  Error_fifo_underflow    : out std_logic;
  Error_reporter_timeout  : out std_logic;
  Error_reporter_overflow : out std_logic
);
end entity intercept_stream_encoder;

architecture rtl of intercept_stream_encoder is

  constant SAMPLE_FIFO_DEPTH  : natural := 512;

  type channel_state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_FORCE,
    S_COAST,
    S_DONE
  );

  type channel_context_t is record
    state               : channel_state_t;

    --TODO: implement
    --power_accum_a       : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    --power_accum_ac      : std_logic;
    --power_accum_b       : unsigned(INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH - 1 downto 0);
    --power_accum_index   : unsigned(INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH - 1 downto 0);

    stream_index        : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
    sample_index        : unsigned(INTERCEPT_STREAM_SAMPLE_INDEX_WIDTH - 1 downto 0);
    coast_index         : unsigned(INTERCEPT_STREAM_COAST_DURATION_WIDTH - 1 downto 0);
  end record;

  type channel_context_array_t is array (natural range <>) of channel_context_t;

  signal m_channel_control              : intercept_message_stream_encoder_channel_control_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0);
  signal m_channel_context              : channel_context_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0);

  signal r_rst                          : std_logic;
  signal r_enable                       : std_logic;
  signal r_dwell_data                   : intercept_dwell_data_t;
  signal w_dwell_data_packed            : std_logic_vector(INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0);
  signal r_dwell_active                 : std_logic;

  signal r_input_ctrl                   : channelizer_control_t;
  signal r_input_data                   : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r_input_pwr                    : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_channel_config_valid         : std_logic;
  signal w_channel_config_index         : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_config_data          : intercept_message_stream_encoder_channel_control_t;
  signal w_stream_config_valid          : std_logic;
  signal w_stream_config_index          : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  signal w_stream_config_data           : intercept_message_stream_encoder_stream_control_t;

  signal w_channel_control_wr_en        : std_logic;
  signal w_channel_control_wr_index     : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_control_wr_data      : intercept_message_stream_encoder_channel_control_t;

  signal r_channel_clear_index          : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0)  := (others => '0');

  signal r0_input_ctrl                  : channelizer_control_t;
  signal r0_input_data                  : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_pwr                   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_channel_control             : intercept_message_stream_encoder_channel_control_t;
  signal r0_context                     : channel_context_t;

  signal r1_input_ctrl                  : channelizer_control_t;
  signal r1_input_data                  : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_pwr                   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_channel_control             : intercept_message_stream_encoder_channel_control_t;
  signal r1_context                     : channel_context_t;

  signal r2_input_ctrl                  : channelizer_control_t;
  signal r2_input_data                  : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r2_input_pwr                   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_channel_control             : intercept_message_stream_encoder_channel_control_t;
  signal r2_context                     : channel_context_t;
  signal r2_detect_start                : std_logic;
  signal r2_detect_continue             : std_logic;
  signal r2_sample_index_next           : unsigned(INTERCEPT_STREAM_SAMPLE_INDEX_WIDTH - 1 downto 0);
  signal r2_coast_index_next            : unsigned(INTERCEPT_STREAM_COAST_DURATION_WIDTH - 1 downto 0);
  signal r2_coast_done                  : std_logic;

  signal r3_input_ctrl                  : channelizer_control_t;
  signal r3_input_data                  : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r3_input_pwr                   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r3_channel_control             : intercept_message_stream_encoder_channel_control_t;
  signal r3_context                     : channel_context_t;
  signal r3_context_wr_index            : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r3_context_wr_valid            : std_logic;
  signal w3_trigger_type                : unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH - 1 downto 0);

  signal r4_output_valid                : std_logic;
  signal r4_output_data                 : intercept_stream_sample_t;
  signal r4_stream_release_valid        : std_logic;
  signal w4_output_data_packed          : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH - 1 downto 0);

  signal w_fifo_wr_data                 : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH + INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0);
  signal w_fifo_rd_data                 : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH + INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0);
  signal w_fifo_rd_en                   : std_logic;
  signal w_fifo_empty                   : std_logic;
  signal w_fifo_overflow                : std_logic;
  signal w_fifo_underflow               : std_logic;

  signal w_stream_sample_data           : intercept_stream_sample_t;
  signal w_stream_dwell_data            : intercept_dwell_data_t;
  signal w_stream_req                   : std_logic;

  signal w_stream_slot_valid            : std_logic;
  signal w_stream_slot_index            : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  signal w_stream_slot_ack              : std_logic;

  signal w_error_reporter_timeout       : std_logic;
  signal w_error_reporter_overflow      : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst           <= Rst;
      r_enable        <= Enable;
      r_dwell_data    <= Dwell_data;
      r_dwell_active  <= Dwell_active;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_ctrl  <= Input_ctrl;
      r_input_data  <= Input_data;
      r_input_pwr   <= Input_pwr;
    end if;
  end process;

  i_config : entity intercept_lib.intercept_stream_config_decoder
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Module_config         => Module_config,

    Channel_config_valid  => w_channel_config_valid,
    Channel_config_index  => w_channel_config_index,
    Channel_config_data   => w_channel_config_data,

    Stream_config_valid   => w_stream_config_valid,
    Stream_config_index   => w_stream_config_index,
    Stream_config_data    => w_stream_config_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_clear_index <= r_channel_clear_index + 1;
    end if;
  end process;

  process(all)
  begin
    if (r_rst = '1') then
      w_channel_control_wr_en     <= '1';
      w_channel_control_wr_index  <= r_channel_clear_index;
      w_channel_control_wr_data   <= (enable => '0', force_trigger => '-', others => (others => '-'));
    else
      w_channel_control_wr_en     <= w_channel_config_valid;
      w_channel_control_wr_index  <= w_channel_config_index;
      w_channel_control_wr_data   <= w_channel_config_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_control_wr_en = '1') then
        m_channel_control(to_integer(w_channel_control_wr_index)) <= w_channel_control_wr_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_ctrl       <= r_input_ctrl;
      r0_input_data       <= r_input_data;
      r0_input_pwr        <= r_input_pwr;
      r0_channel_control  <= m_channel_control(to_integer(r_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_context          <= m_channel_context(to_integer(r_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl       <= r0_input_ctrl;
      r1_input_data       <= r0_input_data;
      r1_input_pwr        <= r0_input_pwr;
      r1_channel_control  <= r0_channel_control;
      r1_context          <= r0_context;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl         <= r1_input_ctrl;
      r2_input_data         <= r1_input_data;
      r2_input_pwr          <= r1_input_pwr;
      r2_channel_control    <= r1_channel_control;
      r2_context            <= r1_context;

      r2_detect_start       <= to_stdlogic(r1_input_pwr > r1_channel_control.threshold_start);
      r2_detect_continue    <= to_stdlogic(r1_input_pwr > r1_channel_control.threshold_continue);
      r2_sample_index_next  <= r1_context.sample_index + 1;
      r2_coast_index_next   <= r1_context.coast_index + 1;
      r2_coast_done         <= to_stdlogic(r1_context.coast_index = r1_channel_control.coast_cycles);
    end if;
  end process;

  w_stream_slot_ack <= to_stdlogic(r2_context.state = S_IDLE) and r2_channel_control.enable and not(r2_channel_control.force_trigger) and r2_detect_start;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl           <= r2_input_ctrl;
      r3_input_data           <= r2_input_data;
      r3_input_pwr            <= r2_input_pwr;
      r3_channel_control      <= r2_channel_control;
      r3_context              <= r2_context;
      r3_context.sample_index <= r2_sample_index_next;
      r3_context.coast_index  <= (others => '0');

      case r2_context.state is
      when S_IDLE =>
        r3_context.stream_index <= (others => '-');
        r3_context.sample_index <= (others => '0');

        if ((r_enable = '1') and (r_dwell_active = '1') and (r2_channel_control.enable = '1')) then
          if (r2_channel_control.force_trigger = '1') then
            r3_context.state          <= S_FORCE;
            r3_context.stream_index   <= r2_channel_control.force_stream;
          elsif ((r2_detect_start = '1') and (w_stream_slot_valid = '1')) then
            r3_context.state          <= S_ACTIVE;
            r3_context.stream_index   <= w_stream_slot_index;
          end if;
        end if;

      when S_ACTIVE =>
        if ((r_enable = '0') or (r_dwell_active = '0') or (r2_channel_control.enable = '0')) then
          r3_context.state <= S_DONE;
        elsif (r2_detect_continue = '0') then
          if (r2_coast_done = '1') then
            r3_context.state <= S_DONE;
          else
            r3_context.state <= S_COAST;
          end if;
        end if;

      when S_FORCE =>
        if ((r_enable = '0') or (r_dwell_active = '0') or (r2_channel_control.enable = '0')) then
          r3_context.state <= S_DONE;
        end if;

      when S_COAST =>
        r3_context.coast_index <= r2_coast_index_next;

        if ((r_enable = '0') or (r_dwell_active = '0') or (r2_channel_control.enable = '0')) then
          r3_context.state <= S_DONE;
        elsif (r2_detect_continue = '1') then
          r3_context.state <= S_ACTIVE;
        elsif (r2_coast_done = '1') then
          r3_context.state <= S_DONE;
        end if;

      when S_DONE =>
        r3_context.state <= S_IDLE;

      end case;

      if (r_rst = '1') then
        r3_context_wr_index <= r_channel_clear_index;
        r3_context_wr_valid <= '1';
        r3_context.state    <= S_IDLE;
      else
        r3_context_wr_index <= r2_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
        r3_context_wr_valid <= r2_input_ctrl.valid;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r3_context_wr_valid = '1') then
        m_channel_context(to_integer(r3_context_wr_index)) <= r3_context;
      end if;
    end if;
  end process;

  process(all)
  begin
    case r3_context.state is
      when S_ACTIVE => w3_trigger_type <= to_unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_NORMAL, INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH);
      when S_COAST  => w3_trigger_type <= to_unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_COAST, INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH);
      when S_FORCE  => w3_trigger_type <= to_unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_FORCED, INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH);
      when others   => w3_trigger_type <= to_unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_LAST, INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH);
    end case;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_output_valid         <= r3_context_wr_valid and to_stdlogic(r3_context.state /= S_IDLE);
      r4_stream_release_valid <= r3_context_wr_valid and to_stdlogic(r3_context.state = S_DONE);

      r4_output_data.trigger_type  <= w3_trigger_type;
      r4_output_data.stream_index  <= r3_context.stream_index;
      r4_output_data.channel_index <= r3_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
      r4_output_data.sample_index  <= r3_context.sample_index;
      r4_output_data.data_i        <= resize_up(r3_input_data(0), r4_output_data.data_i'length);
      r4_output_data.data_q        <= resize_up(r3_input_data(1), r4_output_data.data_q'length);
    end if;
  end process;

  i_stream_manager : entity intercept_lib.intercept_stream_manager
  generic map (
    DATA_WIDTH => DATA_WIDTH
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Config_valid          => w_stream_config_valid,
    Config_index          => w_stream_config_index,
    Config_data           => w_stream_config_data,

    Stream_slot_valid     => w_stream_slot_valid,
    Stream_slot_index     => w_stream_slot_index,
    Stream_slot_ack       => w_stream_slot_ack,

    Stream_release_valid  => r4_stream_release_valid,
    Stream_release_index  => r4_output_data.stream_index
  );

  w4_output_data_packed <= pack(r4_output_data);
  w_dwell_data_packed   <= pack(r_dwell_data);
  w_fifo_wr_data        <= w_dwell_data_packed & w4_output_data_packed;

  i_stream_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH  => SAMPLE_FIFO_DEPTH,
    FIFO_WIDTH  => INTERCEPT_STREAM_SAMPLE_WIDTH + INTERCEPT_DWELL_DATA_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    Wr_en         => r4_output_valid,
    Wr_data       => w_fifo_wr_data,
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_fifo_rd_en,
    Rd_data       => w_fifo_rd_data,
    Empty         => w_fifo_empty,

    Overflow      => w_fifo_overflow,
    Underflow     => w_fifo_underflow
  );

  w_stream_req          <= not(w_fifo_empty);
  w_stream_sample_data  <= unpack(w_fifo_rd_data(INTERCEPT_STREAM_SAMPLE_WIDTH - 1 downto 0));
  w_stream_dwell_data   <= unpack(w_fifo_rd_data(INTERCEPT_STREAM_SAMPLE_WIDTH + INTERCEPT_DWELL_DATA_WIDTH - 1 downto INTERCEPT_STREAM_SAMPLE_WIDTH));

  i_reporter : entity intercept_lib.intercept_stream_reporter
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk_axi         => Clk_axi,
    Clk             => Clk,
    Rst             => r_rst,

    Stream_req      => w_stream_req,
    Stream_sample   => w_stream_sample_data,
    Stream_dwell    => w_stream_dwell_data,
    Stream_ack      => w_fifo_rd_en,

    Axis_ready      => Axis_ready,
    Axis_valid      => Axis_valid,
    Axis_data       => Axis_data,
    Axis_last       => Axis_last,

    Error_timeout   => w_error_reporter_timeout,
    Error_overflow  => w_error_reporter_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_fifo_overflow     <= w_fifo_overflow;
      Error_fifo_underflow    <= w_fifo_underflow;
      Error_reporter_timeout  <= w_error_reporter_timeout;
      Error_reporter_overflow <= w_error_reporter_overflow;
    end if;
  end process;

end architecture rtl;
