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
  OUTPUT_DATA_WIDTH   : natural;
  TAG_WIDTH           : natural;
  ANALYSIS_MODE       : boolean
);
port (
  Clk                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_index           : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_last            : in  std_logic;
  Input_tag             : in  unsigned(TAG_WIDTH - 1 downto 0);
  Input_curr_iq         : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_prev_iq         : in  signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;
  Output_index          : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_last           : out std_logic;
  Output_tag            : out unsigned(TAG_WIDTH - 1 downto 0);
  Output_iq             : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity pfb_filter_stage;

architecture rtl of pfb_filter_stage is

  function get_filter_stage_latency return natural is
  begin
    if (ANALYSIS_MODE) then
      return 3;
    else
      return 4;
    end if;
  end;

  signal r0_input_valid     : std_logic;
  signal r0_input_index     : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r0_input_last      : std_logic;
  signal r0_input_curr_iq   : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_input_prev_iq   : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r0_input_tag       : unsigned(TAG_WIDTH - 1 downto 0);

  signal r1_input_valid     : std_logic;
  signal r1_input_index     : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r1_input_last      : std_logic;
  signal r1_input_curr_iq   : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r1_input_prev_iq   : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r1_input_tag       : unsigned(TAG_WIDTH - 1 downto 0);
  signal r1_coef_data       : signed(COEF_WIDTH - 1 downto 0);

  signal r2_input_valid     : std_logic_vector(1 downto 0);
  signal r2_input_index     : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r2_input_last      : std_logic;
  signal r2_input_sub_index : unsigned(0 downto 0);
  signal r2_input_curr_iq   : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r2_input_prev_iq   : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r2_input_tag       : unsigned(TAG_WIDTH - 1 downto 0);
  signal r2_coef_data       : signed(COEF_WIDTH - 1 downto 0);

  signal r3_input_valid     : std_logic_vector(1 downto 0);
  signal r3_input_index     : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r3_input_last      : std_logic;
  signal r3_input_sub_index : unsigned(0 downto 0);
  signal r3_input_curr_iq   : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r3_input_prev_iq   : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r3_input_tag       : unsigned(TAG_WIDTH - 1 downto 0);
  signal r3_coef_data       : signed(COEF_WIDTH - 1 downto 0);

  signal w_mult_valid       : std_logic;
  signal w_mult_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_mult_sub_index   : unsigned(0 downto 0);
  signal w_mult_last        : std_logic;
  signal w_mult_tag         : unsigned(TAG_WIDTH - 1 downto 0);
  signal w_mult_data        : signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r_mult_valid       : std_logic;
  signal r_mult_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_mult_sub_index   : unsigned(0 downto 0);
  signal r_mult_data        : signed(OUTPUT_DATA_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_valid    <= Input_valid;
      r0_input_index    <= Input_index;
      r0_input_last     <= Input_last;
      r0_input_tag      <= Input_tag;
      r0_input_curr_iq  <= Input_curr_iq;
      r0_input_prev_iq  <= Input_prev_iq;
      end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_valid    <= r0_input_valid;
      r1_input_index    <= r0_input_index;
      r1_input_last     <= r0_input_last;
      r1_input_tag      <= r0_input_tag;
      r1_input_curr_iq  <= r0_input_curr_iq;
      r1_input_prev_iq  <= r0_input_prev_iq;
      r1_coef_data      <= COEF_DATA(to_integer(r0_input_index));
      end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r1_input_valid = '1') then
        r2_input_valid     <= (others => '1');
        r2_input_curr_iq   <= r1_input_curr_iq;
        r2_input_prev_iq   <= r1_input_prev_iq;
        r2_input_sub_index <= "1";
      else
        r2_input_valid      <= r2_input_valid(0)   & '0';
        r2_input_curr_iq(1) <= r2_input_curr_iq(0);
        r2_input_curr_iq(0) <= (others => '0');
        r2_input_prev_iq(1) <= r2_input_prev_iq(0);
        r2_input_prev_iq(0) <= (others => '0');
        r2_input_sub_index  <= "0";
      end if;

      if (r1_input_valid = '1') then
        r2_input_index  <= r1_input_index;
        r2_input_last   <= r1_input_last;
        r2_input_tag    <= r1_input_tag;
        r2_coef_data    <= r1_coef_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_valid      <= r2_input_valid;
      r3_input_index      <= r2_input_index;
      r3_input_sub_index  <= r2_input_sub_index;
      r3_input_last       <= r2_input_last;
      r3_input_curr_iq    <= r2_input_curr_iq;
      r3_input_tag        <= r2_input_tag;
      r3_coef_data        <= r2_coef_data;
      r3_input_prev_iq    <= r2_input_prev_iq;
    end if;
  end process;

  i_mult : entity dsp_lib.pfb_filter_mult
  generic map (
    INDEX_WIDTH         => CHANNEL_INDEX_WIDTH,
    SUB_INDEX_WIDTH     => 1,
    INPUT_A_DATA_WIDTH  => INPUT_DATA_WIDTH,
    INPUT_B_DATA_WIDTH  => COEF_WIDTH,
    INPUT_B_FRAC_WIDTH  => COEF_WIDTH - 1,
    INPUT_C_DATA_WIDTH  => OUTPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    TAG_WIDTH           => TAG_WIDTH,
    LATENCY             => get_filter_stage_latency
  )
  port map (
    Clk             => Clk,

    Input_valid     => r3_input_valid(1),
    Input_index     => r3_input_index,
    Input_sub_index => r3_input_sub_index,
    Input_last      => r3_input_last,
    Input_tag       => r3_input_tag,
    Input_a         => r3_input_curr_iq(1),
    Input_b         => r3_coef_data,
    Input_c         => r3_input_prev_iq(1),

    Output_valid      => w_mult_valid,
    Output_index      => w_mult_index,
    Output_sub_index  => w_mult_sub_index,
    Output_last       => w_mult_last,
    Output_tag        => w_mult_tag,
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

  -- PSL assert always (Output_valid = '1') -> ((r_mult_valid = '1') and (w_mult_index = r_mult_index) and (r_mult_sub_index = 1));

  Output_valid  <= w_mult_valid and to_stdlogic(w_mult_sub_index = 0);
  Output_index  <= w_mult_index;
  Output_last   <= w_mult_last;
  Output_tag    <= w_mult_tag;
  Output_iq(0)  <= w_mult_data;
  Output_iq(1)  <= r_mult_data;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= r0_input_valid and r1_input_valid;
    end if;
  end process;

end architecture rtl;
