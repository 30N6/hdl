library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity pfb_filter is
generic (
  NUM_CHANNELS        : natural;
  CHANNEL_INDEX_WIDTH : natural;
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
  COEF_WIDTH          : natural;
  NUM_COEFS           : natural;
  COEF_DATA           : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0)
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_index           : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_last            : in  std_logic;
  Input_i               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;
  Output_index          : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_last           : out std_logic;
  Output_i              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
end entity pfb_filter;

architecture rtl of pfb_filter is

  constant NUM_COEFS_PER_CHANNEL : natural := NUM_COEFS / NUM_CHANNELS;

  function get_coefs_for_stage(stage : natural) return signed_array_t is
    variable r : signed_array_t(NUM_CHANNELS - 1 downto 0)(COEF_WIDTH - 1 downto 0);
  begin
    for channel in 0 to (NUM_CHANNELS - 1) loop
      r(channel) := COEF_DATA(stage * NUM_CHANNELS + channel);
    end loop;
    return r;
  end function;

  subtype iq_output_data_t is signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  type stage_iq_array_t is array (natural range <>) of iq_output_data_t;

  signal r_input_valid        : std_logic;
  signal r_input_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_input_last         : std_logic;
  signal r_input_iq           : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_stage_prev_iq      : stage_iq_array_t(NUM_COEFS_PER_CHANNEL - 1 downto 0);
  signal w_stage_output_valid : std_logic_vector(NUM_COEFS_PER_CHANNEL - 1 downto 0);
  signal w_stage_output_index : unsigned_array_t(NUM_COEFS_PER_CHANNEL - 1 downto 0)(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_stage_output_last  : std_logic_vector(NUM_COEFS_PER_CHANNEL - 1 downto 0);
  signal w_stage_output_iq    : stage_iq_array_t(NUM_COEFS_PER_CHANNEL - 1 downto 0);
  signal w_stage_overflow     : std_logic_vector(NUM_COEFS_PER_CHANNEL - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_valid <= Input_valid;
      r_input_index <= Input_index;
      r_input_last  <= Input_last;
      r_input_iq    <= Input_i & Input_q;
    end if;
  end process;

  g_stages : for i in 0 to (NUM_COEFS_PER_CHANNEL - 1) generate
    i_filter_stage : entity dsp_lib.pfb_filter_stage
    generic map (
      NUM_CHANNELS        => NUM_CHANNELS,
      CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
      COEF_WIDTH          => COEF_WIDTH,
      COEF_DATA           => get_coefs_for_stage(i),
      INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
      OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH
    )
    port map (
      Clk                   => Clk,

      Input_valid           => r_input_valid,
      Input_index           => r_input_index,
      Input_last            => r_input_last,
      Input_curr_iq         => r_input_iq,
      Input_prev_iq         => w_stage_prev_iq(i),

      Output_valid          => w_stage_output_valid(i),
      Output_index          => w_stage_output_index(i),
      Output_last           => w_stage_output_last(i),
      Output_iq             => w_stage_output_iq(i),

      Error_input_overflow  => w_stage_overflow(i)
    );

    g_buffer : if (i < (NUM_COEFS_PER_CHANNEL - 1)) generate
      i_buffer : entity dsp_lib.pfb_filter_buffer
      generic map (
        CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
        DATA_WIDTH          => OUTPUT_DATA_WIDTH
      )
      port map (
        Clk           => Clk,
        Rst           => Rst,

        Input_valid   => w_stage_output_valid(i + 1),
        Input_index   => w_stage_output_index(i + 1),
        Input_last    => w_stage_output_last(i + 1),
        Input_data    => w_stage_output_iq(i + 1),

        Output_valid  => r_input_valid,
        Output_index  => r_input_index,
        Output_last   => r_input_last,
        Output_data   => w_stage_prev_iq(i)
      );
    else generate
      w_stage_prev_iq(i) <= (others => (others => '0'));
    end generate g_buffer;
  end generate;

  Output_valid          <= w_stage_output_valid(0);
  Output_index          <= w_stage_output_index(0);
  Output_last           <= w_stage_output_last(0);
  (Output_i, Output_q)  <= w_stage_output_iq(0);

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= or_reduce(w_stage_overflow);
    end if;
  end process;

end architecture rtl;
