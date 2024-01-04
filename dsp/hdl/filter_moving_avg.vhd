library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

entity filter_moving_avg is
generic (
  WINDOW_LENGTH : natural;
  LATENCY       : natural;
  INPUT_WIDTH   : natural;
  OUTPUT_WIDTH  : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_data    : in  unsigned(INPUT_WIDTH - 1 downto 0);

  Output_valid  : out std_logic;
  Output_data   : out unsigned(OUTPUT_WIDTH - 1 downto 0)
);
end entity filter_moving_avg;

architecture rtl of filter_moving_avg is

  type input_data_array_t is array (natural range <>) of unsigned(INPUT_WIDTH - 1 downto 0);

  constant WINDOW_BIT_WIDTH : natural := clog2(WINDOW_LENGTH);
  constant ACCUM_WIDTH      : natural := INPUT_WIDTH + WINDOW_BIT_WIDTH;  --TODO: extra bit needed? make sure the "overflow" case is tested

  signal r_rst              : std_logic;

  signal w_input_valid      : std_logic;
  signal w_input_data       : unsigned(INPUT_WIDTH - 1 downto 0);

  signal m_data_pipe        : input_data_array_t(WINDOW_LENGTH - 1 downto 0);
  signal w_delayed_data     : unsigned(INPUT_WIDTH - 1 downto 0);

  signal r_accumulator      : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r_output_valid     : std_logic;

begin

  assert (WINDOW_LENGTH <= 64)
    report "WINDOW_LENGTH expected to be 64 or less. Otherwise, the sample pipeline may not efficiently fit into SRLs."
    severity failure;

  assert (LATENCY = (WINDOW_LENGTH + 1))
    report "Unexpected latency specified."
    severity failure;

  assert (OUTPUT_WIDTH >= INPUT_WIDTH)
    report "Output width must be greater than or equal to the input width."
    severity failure;

  assert (OUTPUT_WIDTH <= ACCUM_WIDTH)
    report "Output width must be less than or equal to the accumulator width."
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
      if (w_input_valid = '1') then
        m_data_pipe <= m_data_pipe(WINDOW_LENGTH - 2 downto 0) & w_input_data;
      end if;
    end if;
  end process;

  w_delayed_data <= m_data_pipe(WINDOW_LENGTH - 1);

  process(Clk)
    variable v_accum : unsigned(ACCUM_WIDTH - 1 downto 0);
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_output_valid  <= '0';
        r_accumulator   <= (others => '0');
      else
        r_output_valid  <= Input_valid;

        if (Input_valid = '1') then
          v_accum       := r_accumulator;
          v_accum       := v_accum + Input_data;
          v_accum       := v_accum - w_delayed_data;
          r_accumulator <= v_accum;
        end if;
      end if;
    end if;
  end process;

  Output_valid  <= r_output_valid;
  Output_data   <= r_accumulator(ACCUM_WIDTH - 1 downto (ACCUM_WIDTH - OUTPUT_WIDTH));  -- not rounding to simplify logic

end architecture rtl;
