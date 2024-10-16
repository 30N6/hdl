library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity pfb_demux_2x is
generic (
  NUM_CHANNELS        : natural;
  CHANNEL_INDEX_WIDTH : natural;
  DATA_WIDTH          : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;  -- 1/4 expected rate
  Input_i               : in  signed(DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed(DATA_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;  -- 1/2 expected rate
  Output_channel        : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_last           : out std_logic;
  Output_i              : out signed(DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic;
  Warning_input_gap     : out std_logic
);
end entity pfb_demux_2x;

architecture rtl of pfb_demux_2x is

  constant BUFFER_DEPTH       : natural := 2 * NUM_CHANNELS;
  constant BUFFER_INDEX_WIDTH : natural := clog2(BUFFER_DEPTH);
  constant READ_CYCLE_COUNT   : natural := 2 * BUFFER_DEPTH;
  constant READ_CYCLE_WIDTH   : natural := clog2(READ_CYCLE_COUNT);

  function get_read_index_map return unsigned_array_t is
    variable r : unsigned_array_t(READ_CYCLE_COUNT - 1 downto 0)(BUFFER_INDEX_WIDTH - 1 downto 0);
  begin
    if (NUM_CHANNELS = 8) then
      for i in 0 to 7 loop
        r(i) := to_unsigned(i, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 8 to 15 loop
        r(i) := to_unsigned(i - 4, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 16 to 23 loop
        r(i) := to_unsigned(i - 8, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 24 to 27 loop
        r(i) := to_unsigned(i - 12, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 28 to 31 loop
        r(i) := to_unsigned(i - 28, BUFFER_INDEX_WIDTH);
      end loop;

    elsif (NUM_CHANNELS = 16) then
      for i in 0 to 15 loop
        r(i) := to_unsigned(i, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 16 to 31 loop
        r(i) := to_unsigned(i - 8, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 32 to 47 loop
        r(i) := to_unsigned(i - 16, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 48 to 55 loop
        r(i) := to_unsigned(i - 24, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 56 to 63 loop
        r(i) := to_unsigned(i - 56, BUFFER_INDEX_WIDTH);
      end loop;

    elsif (NUM_CHANNELS = 32) then
      for i in 0 to 31 loop
        r(i) := to_unsigned(i, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 32 to 63 loop
        r(i) := to_unsigned(i - 16, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 64 to 95 loop
        r(i) := to_unsigned(i - 32, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 96 to 111 loop
        r(i) := to_unsigned(i - 48, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 112 to 127 loop
        r(i) := to_unsigned(i - 112, BUFFER_INDEX_WIDTH);
      end loop;

    elsif (NUM_CHANNELS = 64) then
      for i in 0 to 63 loop
        r(i) := to_unsigned(i, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 64 to 127 loop
        r(i) := to_unsigned(i - 32, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 128 to 191 loop
        r(i) := to_unsigned(i - 64, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 192 to 223 loop
        r(i) := to_unsigned(i - 96, BUFFER_INDEX_WIDTH);
      end loop;
      for i in 224 to 255 loop
        r(i) := to_unsigned(i - 224, BUFFER_INDEX_WIDTH);
      end loop;
    end if;
    return r;
  end function;

  constant READ_CYCLE_MAP   : unsigned_array_t(READ_CYCLE_COUNT - 1 downto 0)(BUFFER_INDEX_WIDTH - 1 downto 0) := get_read_index_map;

  type data_array_t is array (natural range <>) of signed(DATA_WIDTH - 1 downto 0);

  signal m_buffer_i         : data_array_t(BUFFER_DEPTH - 1 downto 0);
  signal m_buffer_q         : data_array_t(BUFFER_DEPTH - 1 downto 0);

  signal r_write_index      : unsigned(BUFFER_INDEX_WIDTH - 1 downto 0);
  signal r_write_valid      : std_logic;

  signal r_read_cycle       : unsigned(READ_CYCLE_WIDTH - 1 downto 0);
  signal r_read_index       : unsigned(BUFFER_INDEX_WIDTH - 1 downto 0);
  signal r_read_channel     : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_output_valid     : std_logic;
  signal w_read_cycle_next  : unsigned(READ_CYCLE_WIDTH - 1 downto 0);

  signal r_input_valid      : std_logic_vector(3 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_valid <= r_input_valid(2 downto 0) & Input_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        m_buffer_i(to_integer(r_write_index)) <= Input_i;
        m_buffer_q(to_integer(r_write_index)) <= Input_q;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_write_valid     <= '0';
        r_write_index     <= (others => '0');
      else
        if (Input_valid = '1') then
          r_write_index <= r_write_index + 1;

          if (r_write_index = (NUM_CHANNELS / 2)) then
            r_write_valid <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  --TODO: handle input_valid stops

  w_read_cycle_next <= r_read_cycle + 1;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_cycle      <= (others => '0');
        r_read_index      <= READ_CYCLE_MAP(0);
        r_read_channel    <= (others => '1');
        r_output_valid    <= '0';
      else
        r_output_valid    <= not(r_output_valid) and r_write_valid;
        if (r_output_valid = '1') then
          r_read_cycle    <= w_read_cycle_next;
          r_read_index    <= READ_CYCLE_MAP(to_integer(w_read_cycle_next));
          r_read_channel  <= r_read_channel - 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid   <= r_output_valid;
      Output_channel <= r_read_channel;
      Output_last    <= to_stdlogic(r_read_channel = 0);
      Output_i       <= m_buffer_i(to_integer(r_read_index));
      Output_q       <= m_buffer_q(to_integer(r_read_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow  <= Input_valid and or_reduce(r_input_valid(2 downto 0));
      Warning_input_gap     <= Input_valid and not(or_reduce(r_input_valid));
    end if;
  end process;

end architecture rtl;
