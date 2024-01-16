library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

entity fft_32_stage is
generic (
  DATA_INDEX_WIDTH  : natural;
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  STAGE_INDEX       : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_data_valid      : in  std_logic;
  Input_data_index      : in  unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Input_data_i          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_data_q          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

  Output_data_valid     : out std_logic;
  Output_data_index     : out unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Output_data_i         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_data_q         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
end entity fft_32_stage;

architecture rtl of fft_32_4x is

  constant BUFFER_DATA_WIDTH  : natural := 2*INPUT_DATA_WIDTH;

  constant NUM_READ_CYCLES    : natural := 32;
  constant READ_INDEX_A_S1    : natural_array_t(0 to NUM_READ_CYCLES-1) := (0, 1, 2, 3,   0, 1, 2, 3,   8, 9, 10, 11,     8, 9, 10, 11,       16, 17, 18, 19,   16, 17, 18, 19,   24, 25, 26, 27,   24, 25, 26, 27);
  constant READ_INDEX_B_S1    : natural_array_t(0 to NUM_READ_CYCLES-1) := (4, 5, 6, 7,   4, 5, 6, 7,   12, 13, 14, 15,   12, 13, 14, 15,     20, 21, 22, 23,   20, 21, 22, 23,   28, 29, 30, 31,   28, 29, 30, 31);
  constant READ_INDEX_A_S2    : natural_array_t(0 to NUM_READ_CYCLES-1) := (0, 1, 2,  3,  4,  5,  6,  7,    0, 1, 2,  3,  4,  5,  6,  7,      16, 17, 18, 19, 20, 21, 22, 23,   16, 17, 18, 19, 20, 21, 22, 23);
  constant READ_INDEX_B_S2    : natural_array_t(0 to NUM_READ_CYCLES-1) := (8, 9, 10, 11, 12, 13, 14, 15,   8, 9, 10, 11, 12, 13, 14, 15,     24, 25, 26, 27, 28, 29, 30, 31,   24, 25, 26, 27, 28, 29, 30, 31);
  constant READ_INDEX_A_S3    : natural_array_t(0 to NUM_READ_CYCLES-1) := (0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15);
  constant READ_INDEX_B_S3    : natural_array_t(0 to NUM_READ_CYCLES-1) := (16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,   16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31);


  constant NUM_S0_PIPE_STAGES : natural := 3;
  constant S0_READ_INDEX      : natural_array_t(0 to NUM_S0_CYCLES-1) :=

  type s0_state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_DONE
  );

  signal w_buf_wr_data  : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_addr  : std_logic_vector_array_t(1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_buf_rd_data  : std_logic_vector_array_t(1 downto 0)(BUFFER_DATA_WIDTH - 1 downto 0);

  signal r_calc_active  : std_logic;
  signal r_calc_index   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal r_calc_active_pipe : std_logic_vector(1 downto 0);
  signal r_calc_index_pipe  : unsigned_array_t(1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);


  signal r_s0_wr_en     : std_logic;
  signal r_s0_wr_addr   : std_logic_vector(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_s0_wr_data   : std_logic_vector(S0_DATA_WIDTH - 1 downto 0);
  signal r_s0_start     : std_logic;

  signal w_s0_rd_addr   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_s0_rd_data   : std_logic_vector(S0_DATA_WIDTH - 1 downto 0);

  signal w_s0_rd_index  : unsigned(clog2(NUM_S0_CYCLES) - 1 downto 0);
  signal r_s0_rd_index  : unsigned_array_t(NUM_S0_PIPE_STAGES - 1 downto 0)(clog2(NUM_S0_CYCLES) - 1 downto 0);
  signal r_s0_active    : std_logic_vector(NUM_S0_PIPE_STAGES - 1 downto 0);
  signal r_s0_done      : std_logic_vector(NUM_S0_PIPE_STAGES - 1 downto 0);
  signal s_s0_state     : std_logic;

  signal r_fft4_input_valid   : std_logic;
  signal r_fft4_input_data_i  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_data_q  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_index   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal w_fft4_output_valid  : std_logic;
  signal w_fft4_output_data_i : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_data_q : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_index  : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal r_fft4_output_index  : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_fft4_output_data_i : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal r_fft4_output_data_q : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);

  signal r_s1_wr_en           : std_logic;
  signal r_s1_wr_sub_index    : unsigned(1 downto 0);
  signal w_s1_rd_addr         : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_s1_wr_data         : std_logic_vector(S1_DATA_WIDTH - 1 downto 0);

  signal w_buffer_rd_addr     : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_buffer_rd_data     : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);

begin

  assert ((STAGE_INDEX = 1) or (STAGE_INDEX = 2) or (STAGE_INDEX = 3))
    report "Invalid stage index"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_calc_active <= '0';
        r_calc_index  <= (others => '-');
      else
        if (Input_calc_start = '1') then
          r_calc_active <= '1';
          r_calc_index  <= (others => '0');
        else
          if (r_calc_index = (2**DATA_INDEX_WIDTH - 1)) then
            r_calc_active <= '0';
          end if;
          r_calc_index <= r_calc_index + 1;
        end if;
      end if;
    end if;
  end process;

  w_buf_wr_data <= std_logic_vector(Input_data_i & Input_data_q);

  process(all)
  begin
    if (STAGE_INDEX = 1) then
      w_buf_rd_addr(0) <= READ_INDEX_A_S1(to_integer(r_calc_index));
      w_buf_rd_addr(1) <= READ_INDEX_B_S1(to_integer(r_calc_index));
    elsif (STAGE_INDEX = 2) then
      w_buf_rd_addr(0) <= READ_INDEX_A_S2(to_integer(r_calc_index));
      w_buf_rd_addr(1) <= READ_INDEX_B_S2(to_integer(r_calc_index));
    else
      w_buf_rd_addr(0) <= READ_INDEX_A_S3(to_integer(r_calc_index));
      w_buf_rd_addr(1) <= READ_INDEX_B_S3(to_integer(r_calc_index));
    end if;
  end process;

  g_buffer : for i in 0 to 1 generate
    i_buffer : entity mem_lib.ram_sdp
    generic map (
      ADDR_WIDTH  => DATA_INDEX_WIDTH,
      DATA_WIDTH  => S1_DATA_WIDTH,
      LATENCY     => 2
    )
    port map (
      Clk       => Clk,

      Wr_en     => Input_data_valid,
      Wr_addr   => Input_data_index,
      Wr_data   => w_buf_wr_data,

      Rd_en     => '1',
      Rd_reg_ce => '1',
      Rd_addr   => w_buf_rd_addr(i),
      Rd_data   => w_buf_rd_data(i)
    );
  end generate g_buffer;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_calc_active_pipe <= r_calc_active_pipe(0) & r_calc_active;
      r_calc_index_pipe  <= r_calc_index_pipe(0)  & r_calc_index;
    end if;
  end process;



end architecture rtl;
