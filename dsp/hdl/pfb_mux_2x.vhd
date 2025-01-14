library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity pfb_mux_2x is
generic (
  NUM_CHANNELS        : natural;
  CHANNEL_INDEX_WIDTH : natural;
  INPUT_WIDTH         : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;  -- 1/2 rate
  Input_channel         : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_last            : in  std_logic;
  Input_i               : in  signed(INPUT_WIDTH - 1 downto 0);
  Input_q               : in  signed(INPUT_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;  -- 1/4 rate
  Output_i              : out signed(INPUT_WIDTH downto 0);
  Output_q              : out signed(INPUT_WIDTH downto 0);

  Error_input_overflow  : out std_logic;
  Error_fifo_overflow   : out std_logic;
  Error_fifo_underflow  : out std_logic
);
end entity pfb_mux_2x;

architecture rtl of pfb_mux_2x is

  constant OUTPUT_WIDTH         : natural := INPUT_WIDTH + 1;

  type input_array_t is array (natural range <>) of signed(INPUT_WIDTH - 1 downto 0);
  type output_array_t is array (natural range <>) of signed(OUTPUT_WIDTH - 1 downto 0);

  signal m_buffer_0_i           : input_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));
  signal m_buffer_0_q           : input_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));
  signal m_buffer_1_i           : input_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));
  signal m_buffer_1_q           : input_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));
  signal m_summed_i             : output_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));
  signal m_summed_q             : output_array_t(NUM_CHANNELS/2 - 1 downto 0) := (others => (others => '0'));

  signal r0_input_valid         : std_logic;
  signal r0_input_last          : std_logic;
  signal r0_input_channel       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r0_input_i             : signed(INPUT_WIDTH - 1 downto 0);
  signal r0_input_q             : signed(INPUT_WIDTH - 1 downto 0);
  signal r0_buffer_valid        : std_logic;
  signal r0_buffer_0_i          : signed(INPUT_WIDTH - 1 downto 0);
  signal r0_buffer_0_q          : signed(INPUT_WIDTH - 1 downto 0);
  signal r0_buffer_1_i          : signed(INPUT_WIDTH - 1 downto 0);
  signal r0_buffer_1_q          : signed(INPUT_WIDTH - 1 downto 0);

  signal r1_summed_valid        : std_logic;
  signal r1_summed_last         : std_logic;
  signal r1_summed_channel      : unsigned(CHANNEL_INDEX_WIDTH - 2 downto 0);
  signal r1_summed_i            : signed(OUTPUT_WIDTH - 1 downto 0);
  signal r1_summed_q            : signed(OUTPUT_WIDTH - 1 downto 0);

  signal r2_last_valid          : std_logic;

  signal r_fifo_write_active    : std_logic;
  signal r_fifo_write_index     : unsigned(CHANNEL_INDEX_WIDTH - 2 downto 0);

  signal w_summed_i             : signed(OUTPUT_WIDTH - 1 downto 0);
  signal w_summed_q             : signed(OUTPUT_WIDTH - 1 downto 0);
  signal r_fifo_write_valid     : std_logic;
  signal r_fifo_write_data      : std_logic_vector(OUTPUT_WIDTH * 2 - 1 downto 0);

  signal r_read_cycle           : unsigned(1 downto 0);
  signal w_fifo_rd_en           : std_logic;
  signal w_fifo_rd_data         : std_logic_vector(OUTPUT_WIDTH * 2 - 1 downto 0);
  signal w_fifo_empty           : std_logic;

  signal w_error_input_overflow : std_logic;
  signal w_error_fifo_overflow  : std_logic;
  signal w_error_fifo_underflow : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_valid    <= Input_valid;
      r0_input_last     <= Input_last;
      r0_input_channel  <= Input_channel;
      r0_input_i        <= Input_i;
      r0_input_q        <= Input_q;

      r0_buffer_valid   <= Input_valid and to_stdlogic(Input_channel < (NUM_CHANNELS/2));
      r0_buffer_0_i     <= m_buffer_0_i(to_integer(Input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0)));
      r0_buffer_0_q     <= m_buffer_0_q(to_integer(Input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0)));
      r0_buffer_1_i     <= m_buffer_1_i(to_integer(Input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0)));
      r0_buffer_1_q     <= m_buffer_1_q(to_integer(Input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r0_buffer_valid = '1') then
        m_buffer_0_i(to_integer(r0_input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0))) <= r0_input_i;
        m_buffer_0_q(to_integer(r0_input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0))) <= r0_input_q;
        m_buffer_1_i(to_integer(r0_input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0))) <= r0_buffer_0_i;
        m_buffer_1_q(to_integer(r0_input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0))) <= r0_buffer_0_q;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_summed_valid   <= r0_input_valid and to_stdlogic(r0_input_channel >= (NUM_CHANNELS/2));
      r1_summed_last    <= r0_input_last;
      r1_summed_channel <= r0_input_channel(CHANNEL_INDEX_WIDTH - 2 downto 0);
      r1_summed_i       <= resize_up(r0_input_i, OUTPUT_WIDTH) + resize_up(r0_buffer_1_i, OUTPUT_WIDTH);
      r1_summed_q       <= resize_up(r0_input_q, OUTPUT_WIDTH) + resize_up(r0_buffer_1_q, OUTPUT_WIDTH);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r1_summed_valid = '1') then
        m_summed_i(to_integer(r1_summed_channel)) <= r1_summed_i;
        m_summed_q(to_integer(r1_summed_channel)) <= r1_summed_q;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_last_valid <= (r1_summed_valid and r1_summed_last) or (r0_input_valid and Input_valid);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_fifo_write_active <= '0';
        r_fifo_write_index  <= (others => '-');
      else
        r_fifo_write_index <= r_fifo_write_index - 1;
        if (r_fifo_write_index = 0) then
          r_fifo_write_active <= '0';
        end if;

        if (r2_last_valid = '1') then
          r_fifo_write_active <= '1';
          r_fifo_write_index  <= to_unsigned(NUM_CHANNELS/2 - 1, CHANNEL_INDEX_WIDTH - 1);
        end if;
      end if;
    end if;
  end process;

  w_error_input_overflow <= r2_last_valid and r_fifo_write_active;

  w_summed_i <= m_summed_i(to_integer(r_fifo_write_index));
  w_summed_q <= m_summed_q(to_integer(r_fifo_write_index));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_write_data   <= std_logic_vector(w_summed_i) & std_logic_vector(w_summed_q);
      r_fifo_write_valid  <= r_fifo_write_active;
    end if;
  end process;

  i_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH  => maximum(NUM_CHANNELS / 2, 16),
    FIFO_WIDTH  => OUTPUT_WIDTH * 2
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Wr_en         => r_fifo_write_valid,
    Wr_data       => r_fifo_write_data,
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_fifo_rd_en,
    Rd_data       => w_fifo_rd_data,
    Empty         => w_fifo_empty,

    Overflow      => w_error_fifo_overflow,
    Underflow     => w_error_fifo_underflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_cycle <= (others => '0');
      else
        r_read_cycle <= r_read_cycle + 1;
      end if;
    end if;
  end process;

  w_fifo_rd_en <= not(w_fifo_empty) and to_stdlogic(r_read_cycle = 0);

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid <= w_fifo_rd_en;
      Output_i     <= signed(w_fifo_rd_data(OUTPUT_WIDTH * 2 - 1 downto OUTPUT_WIDTH));
      Output_q     <= signed(w_fifo_rd_data(OUTPUT_WIDTH - 1 downto 0));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow  <= w_error_input_overflow;
      Error_fifo_overflow   <= w_error_fifo_overflow;
      Error_fifo_underflow  <= w_error_fifo_underflow;
    end if;
  end process;

end architecture rtl;
