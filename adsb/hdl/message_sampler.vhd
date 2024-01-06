library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;

library adsb_lib;
  use adsb_lib.adsb_pkg.all;

entity message_sampler is
generic (
  PREAMBLE_LENGTH     : natural;
  PREAMBLE_S_WIDTH    : natural;
  PREAMBLE_SN_WIDTH   : natural;
  FILTERED_MAG_WIDTH  : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Enable              : in  std_logic;
  Timestamp           : in  timestamp_t;

  Input_valid         : in  std_logic;
  Input_start         : in  std_logic;
  Input_filtered_mag  : in  unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  Input_preamble_s    : in  unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  Input_preamble_sn   : in  unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);

  Output_valid        : out std_logic;
  Output_message_data : out adsb_message_t;
  Output_preamble_s   : out unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  Output_preamble_sn  : out unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);
  Output_crc_match    : out std_logic;
  Output_timestamp    : out timestamp_t
);
end entity message_sampler;

architecture rtl of message_sampler is

  constant MESSAGE_START_DELAY      : natural := 32 + 4; -- 32 cycles for preamble, 4 cycles to sample in the middle of each bit
  constant CYCLES_PER_BIT           : natural := 8;
  constant DYNAMIC_THRESHOLD_CYCLE  : natural := 8; -- switch to the dynamic threshold after a while

  type state_t is
  (
    S_IDLE,
    S_WAIT_START,
    S_SAMPLE,
    S_WAIT_SAMPLE,
    S_DONE
  );

  signal s_state                : state_t;

  signal r_enable               : std_logic;

  signal r_latched_timestamp    : timestamp_t;
  signal r_latched_preamble_s   : unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  signal r_latched_preamble_sn  : unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);

  signal r_start_wait_count     : unsigned(clog2(MESSAGE_START_DELAY) - 1 downto 0);

  signal r_message_bit_count    : unsigned(clog2(ADSB_MESSAGE_WIDTH) - 1 downto 0);
  signal r_message_data         : adsb_message_t;

  signal r_sample_wait_count    : unsigned(clog2(CYCLES_PER_BIT) - 1 downto 0);

  signal w_avg_filtered_mag     : unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  signal r_bit_threshold        : unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  signal w_sampled_bit          : std_logic;

begin

  -- could use the preamble s+n data instead
  i_mag_avg : entity dsp_lib.filter_moving_avg
  generic map (
    WINDOW_LENGTH => PREAMBLE_LENGTH,
    LATENCY       => PREAMBLE_LENGTH + 1,
    INPUT_WIDTH   => FILTERED_MAG_WIDTH,
    OUTPUT_WIDTH  => FILTERED_MAG_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Input_valid   => Input_valid,
    Input_data    => Input_filtered_mag,

    Output_valid  => open,
    Output_data   => w_avg_filtered_mag
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_enable <= Enable;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if ((r_enable = '1') and (Input_valid = '1') and (Input_start = '1')) then
            s_state <= S_WAIT_START;
          else
            s_state <= S_IDLE;
          end if;

        when S_WAIT_START =>
          if (r_start_wait_count = (MESSAGE_START_DELAY - 1)) then
            s_state <= S_SAMPLE;
          else
            s_state <= S_WAIT_START;
          end if;

        when S_SAMPLE =>
          if (r_message_bit_count = (ADSB_MESSAGE_WIDTH - 1)) then
            s_state <= S_DONE;
          else
            s_state <= S_WAIT_SAMPLE;
          end if;

        when S_WAIT_SAMPLE =>
          if (r_sample_wait_count = (CYCLES_PER_BIT - 1)) then
            s_state <= S_SAMPLE;
          else
            s_state <= S_WAIT_SAMPLE;
          end if;

        when S_DONE =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_latched_timestamp   <= Timestamp;
        r_latched_preamble_s  <= Input_preamble_s;
        r_latched_preamble_sn <= Input_preamble_sn;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_start_wait_count <= (others => '0');
      else
        r_start_wait_count <= r_start_wait_count + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_message_bit_count <= (others => '0');
        r_message_data      <= (others => '-');
      elsif (s_state = S_SAMPLE) then
        r_message_bit_count <= r_message_bit_count + 1;
        r_message_data      <= r_message_data(ADSB_MESSAGE_WIDTH - 2 downto 0) & w_sampled_bit;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_SAMPLE) then
        r_sample_wait_count <= (others => '0');
      else
        r_sample_wait_count <= r_sample_wait_count + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_message_bit_count < DYNAMIC_THRESHOLD_CYCLE) then
        r_bit_threshold <= resize_up(r_latched_preamble_s(PREAMBLE_S_WIDTH - 2 downto 0), FILTERED_MAG_WIDTH);   --TODO: check scaling
      else
        r_bit_threshold <= '0' & w_avg_filtered_mag(FILTERED_MAG_WIDTH - 2 downto 0);
      end if;
    end if;
  end process;

  w_sampled_bit <= to_stdlogic(Input_filtered_mag > r_bit_threshold);

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid        <= to_stdlogic(s_state = S_DONE);
      Output_message_data <= r_message_data;
      Output_preamble_s   <= r_latched_preamble_s;
      Output_preamble_sn  <= r_latched_preamble_sn;
      Output_crc_match    <= '1'; --TODO: crc check
      Output_timestamp    <= r_latched_timestamp;
    end if;
  end process;

end architecture rtl;
