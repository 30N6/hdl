library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

-- out = A * B + C

entity pfb_filter_mult is
generic (
  INDEX_WIDTH         : natural;
  SUB_INDEX_WIDTH     : natural;
  INPUT_A_DATA_WIDTH  : natural;
  INPUT_B_DATA_WIDTH  : natural;
  INPUT_B_FRAC_WIDTH  : natural;
  INPUT_C_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH   : natural;
  TAG_WIDTH           : natural;
  LATENCY             : natural
);
port (
  Clk               : in  std_logic;

  Input_valid       : in  std_logic;
  Input_index       : in  unsigned(INDEX_WIDTH - 1 downto 0);
  Input_sub_index   : in  unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  Input_last        : in  std_logic;
  Input_tag         : in  unsigned(TAG_WIDTH - 1 downto 0);
  Input_a           : in  signed(INPUT_A_DATA_WIDTH - 1 downto 0);
  Input_b           : in  signed(INPUT_B_DATA_WIDTH - 1 downto 0);
  Input_c           : in  signed(INPUT_C_DATA_WIDTH - 1 downto 0);

  Output_valid      : out std_logic;
  Output_index      : out unsigned(INDEX_WIDTH - 1 downto 0);
  Output_sub_index  : out unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  Output_last       : out std_logic;
  Output_tag        : out unsigned(TAG_WIDTH - 1 downto 0);
  Output_data       : out signed(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity pfb_filter_mult;

architecture rtl of pfb_filter_mult is

  constant MULT_RESULT_WIDTH  : natural := INPUT_A_DATA_WIDTH + INPUT_B_DATA_WIDTH;
  constant MULT_SCALED_WIDTH  : natural := MULT_RESULT_WIDTH - INPUT_B_FRAC_WIDTH;

  signal r0_input_valid       : std_logic;
  signal r0_input_index       : unsigned(INDEX_WIDTH - 1 downto 0);
  signal r0_input_sub_index   : unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  signal r0_input_last        : std_logic;
  signal r0_input_tag         : unsigned(TAG_WIDTH - 1 downto 0);
  signal r0_input_a           : signed(INPUT_A_DATA_WIDTH - 1 downto 0);
  signal r0_input_b           : signed(INPUT_B_DATA_WIDTH - 1 downto 0);
  signal r0_input_c           : signed(INPUT_C_DATA_WIDTH - 1 downto 0);

  signal r1_valid             : std_logic;
  signal r1_index             : unsigned(INDEX_WIDTH - 1 downto 0);
  signal r1_sub_index         : unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  signal r1_last              : std_logic;
  signal r1_mult_result       : signed(MULT_RESULT_WIDTH - 1 downto 0);
  signal r1_input_c           : signed(INPUT_C_DATA_WIDTH - 1 downto 0);
  signal r1_tag               : unsigned(TAG_WIDTH - 1 downto 0);
  signal w1_mult_scaled       : signed(MULT_SCALED_WIDTH - 1 downto 0);

  signal r2_valid             : std_logic;
  signal r2_index             : unsigned(INDEX_WIDTH - 1 downto 0);
  signal r2_sub_index         : unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  signal r2_last              : std_logic;
  signal r2_tag               : unsigned(TAG_WIDTH - 1 downto 0);
  signal r2_sum               : signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r2_mult_result       : signed(MULT_RESULT_WIDTH - 1 downto 0);
  signal r2_input_c           : signed(INPUT_C_DATA_WIDTH - 1 downto 0);
  signal w2_mult_scaled       : signed(MULT_SCALED_WIDTH - 1 downto 0);

  signal r3_valid             : std_logic;
  signal r3_index             : unsigned(INDEX_WIDTH - 1 downto 0);
  signal r3_sub_index         : unsigned(SUB_INDEX_WIDTH - 1 downto 0);
  signal r3_last              : std_logic;
  signal r3_tag               : unsigned(TAG_WIDTH - 1 downto 0);
  signal r3_sum               : signed(OUTPUT_DATA_WIDTH - 1 downto 0);

begin

  assert ((LATENCY = 3) or (LATENCY = 4))
    report "Latency expected to be 3 or 4."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_valid      <= Input_valid;
      r0_input_index      <= Input_index;
      r0_input_sub_index  <= Input_sub_index;
      r0_input_last       <= Input_last;
      r0_input_tag        <= Input_tag;
      r0_input_a          <= Input_a;
      r0_input_b          <= Input_b;
      r0_input_c          <= Input_c;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_valid        <= r0_input_valid;
      r1_index        <= r0_input_index;
      r1_sub_index    <= r0_input_sub_index;
      r1_last         <= r0_input_last;
      r1_tag          <= r0_input_tag;
      r1_mult_result  <= r0_input_b * r0_input_a;
      r1_input_c      <= r0_input_c;
    end if;
  end process;

  g_output : if (LATENCY = 3) generate

    w1_mult_scaled <= r1_mult_result(MULT_RESULT_WIDTH - 1 downto INPUT_B_FRAC_WIDTH);  --shift_left(r1_mult_result, INPUT_B_FRAC_WIDTH);

    process(Clk)
    begin
      if rising_edge(Clk) then
        r2_valid      <= r1_valid;
        r2_index      <= r1_index;
        r2_sub_index  <= r1_sub_index;
        r2_last       <= r1_last;
        r2_tag        <= r1_tag;
        r2_sum        <= resize_up(w1_mult_scaled, OUTPUT_DATA_WIDTH) + r1_input_c;
      end if;
    end process;

    Output_valid      <= r2_valid;
    Output_index      <= r2_index;
    Output_sub_index  <= r2_sub_index;
    Output_last       <= r2_last;
    Output_tag        <= r2_tag;
    Output_data       <= r2_sum;

  else generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        r2_valid        <= r1_valid;
        r2_index        <= r1_index;
        r2_sub_index    <= r1_sub_index;
        r2_last         <= r1_last;
        r2_tag          <= r1_tag;
        r2_mult_result  <= r1_mult_result;
        r2_input_c      <= r1_input_c;
      end if;
    end process;

    w2_mult_scaled <= r2_mult_result(MULT_RESULT_WIDTH - 1 downto INPUT_B_FRAC_WIDTH);  --shift_left(r2_mult_result, INPUT_B_FRAC_WIDTH);

    process(Clk)
    begin
      if rising_edge(Clk) then
        r3_valid      <= r2_valid;
        r3_index      <= r2_index;
        r3_sub_index  <= r2_sub_index;
        r3_last       <= r2_last;
        r3_tag        <= r2_tag;
        r3_sum        <= resize_up(w2_mult_scaled, OUTPUT_DATA_WIDTH) + r2_input_c;
      end if;
    end process;

    Output_valid      <= r3_valid;
    Output_index      <= r3_index;
    Output_sub_index  <= r3_sub_index;
    Output_last       <= r3_last;
    Output_tag        <= r3_tag;
    Output_data       <= r3_sum;

  end generate g_output;

end architecture rtl;
