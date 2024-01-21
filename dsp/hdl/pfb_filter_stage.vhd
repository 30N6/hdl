library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity pfb_filter_stage is
generic (
  NUM_CHANNELS        : natural;
  CHANNEL_INDEX_WIDTH : natural;
  COEF_WIDTH          : natural;
  COEF_DATA           : signed_array_t(NUM_CHANNELS - 1 downto 0)(COEF_WIDTH - 1 downto 0);
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural
);
port (
  Clk                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_index           : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_curr_iq         : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_prev_iq         : in  signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;
  Output_index          : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_iq             : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
end entity pfb_filter_stage;

architecture rtl of pfb_filter_stage is

  signal w_coef_data        : signed(COEF_WIDTH - 1 downto 0);

  signal r_input_valid      : std_logic_vector(1 downto 0);
  signal r_input_index      : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_input_sub_index  : unsigned(0 downto 0);
  signal r_input_curr_iq    : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_input_prev_iq    : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal w_mult_valid       : std_logic;
  signal w_mult_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_mult_sub_index   : unsigned(0 downto 0);
  signal w_mult_data        : signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r_mult_valid       : std_logic;
  signal r_mult_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_mult_sub_index   : unsigned(0 downto 0);
  signal r_mult_data        : signed(OUTPUT_DATA_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        r_input_valid   <= (others => '1');
        r_input_curr_iq <= Input_curr_iq;
        r_input_prev_iq <= Input_prev_iq;
      else
        r_input_valid      <= r_input_valid(0)   & '0';
        r_input_curr_iq(1) <= r_input_curr_iq(0);
        r_input_curr_iq(0) <= (others => '-');
        r_input_prev_iq(1) <= r_input_prev_iq(0);
        r_input_prev_iq(0) <= (others => '-');
      end if;

      if (Input_valid = '1') then
        r_input_index <= Input_index;
      end if;
    end if;
  end process;

  w_coef_data <= COEF_DATA(to_integer(r_input_index));

  i_mult : entity dsp_lib.pfb_filter_mult
  generic map (
    INDEX_WIDTH         => CHANNEL_INDEX_WIDTH,
    SUB_INDEX_WIDTH     => 1,
    INPUT_A_DATA_WIDTH  => INPUT_DATA_WIDTH,
    INPUT_B_DATA_WIDTH  => COEF_WIDTH,
    INPUT_B_FRAC_WIDTH  => COEF_WIDTH - 1,
    INPUT_C_DATA_WIDTH  => OUTPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    LATENCY             => 3
  )
  port map (
    Clk             => Clk,

    Input_valid     => r_input_valid(1),
    Input_index     => r_input_index,
    Input_sub_index => r_input_sub_index,
    Input_a         => r_input_curr_iq(1),
    Input_b         => w_coef_data,
    Input_c         => r_input_prev_iq(1),

    Output_valid      => w_mult_valid,
    Output_index      => w_mult_index,
    Output_sub_index  => w_mult_sub_index,
    Output_data       => w_mult_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_mult_valid      <= w_mult_valid;
      r_mult_data       <= w_mult_data;
      r_mult_index      <= w_mult_index;
      r_mult_sub_index  <= w_mult_sub_index;
    end if;
  end process;

  Output_valid  <= w_mult_valid and to_stdlogic(w_mult_sub_index = 1);
  Output_index  <= w_mult_index;
  Output_iq(0)  <= w_mult_data;
  Output_iq(1)  <= r_mult_data;

  assert ((Output_valid = '0') or ((r_mult_valid = '1') and (w_mult_index = r_mult_index) and (r_mult_sub_index = 0)))
    report "Unexpected data from multiplier."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= Input_valid and r_input_valid(0);
    end if;
  end process;

end architecture rtl;
