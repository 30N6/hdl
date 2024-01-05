library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

entity correlator_simple is
generic (
  CORRELATION_LENGTH  : natural;
  CORRELATION_DATA    : std_logic_vector(0 to CORRELATION_LENGTH - 1);
  LATENCY             : natural;
  INPUT_WIDTH         : natural;
  OUTPUT_WIDTH        : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_data    : in  unsigned(INPUT_WIDTH - 1 downto 0);

  Output_valid  : out std_logic;
  Output_data   : out unsigned(OUTPUT_WIDTH - 1 downto 0)
);
end entity correlator_simple;

architecture rtl of correlator_simple is

  constant WINDOW_BIT_WIDTH : natural := clog2(CORRELATION_LENGTH);
  constant SUM_WIDTH        : natural := INPUT_WIDTH + WINDOW_BIT_WIDTH;

  type input_data_array_t   is array (natural range <>) of unsigned(INPUT_WIDTH - 1 downto 0);
  type sum_data_array_t     is array (natural range <>) of unsigned(SUM_WIDTH - 1 downto 0);

  signal r_rst              : std_logic;

  signal w_input_valid      : std_logic;
  signal w_input_data       : unsigned(INPUT_WIDTH - 1 downto 0);

  signal r_sum_pipe         : sum_data_array_t(CORRELATION_LENGTH - 1 downto 0);
  signal r_sum_valid        : std_logic;

begin

  assert (LATENCY = (CORRELATION_LENGTH + 1))
    report "Unexpected latency specified."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  w_input_valid <= Input_valid  when (r_rst = '0') else '1';
  w_input_data  <= Input_data   when (r_rst = '0') else (others => '0');

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_sum_valid <= Input_valid;

      if (w_input_valid = '1') then
        for i in 0 to (CORRELATION_LENGTH - 1) loop
          if (i = 0) then
            if (CORRELATION_DATA(i) = '1') then
              r_sum_pipe(i) <= resize_up(w_input_data, SUM_WIDTH);
            else
              r_sum_pipe(i) <= (others => '0');
            end if;
          else
            if (CORRELATION_DATA(i) = '1') then
              r_sum_pipe(i) <= r_sum_pipe(i - 1) + w_input_data;
            else
              r_sum_pipe(i) <= r_sum_pipe(i - 1);
            end if;
          end if;
        end loop;
      end if;
    end if;
  end process;

  Output_valid  <= r_sum_valid;
  Output_data   <= r_sum_pipe(CORRELATION_LENGTH - 1)(SUM_WIDTH - 1 downto (SUM_WIDTH - OUTPUT_WIDTH));

end architecture rtl;
