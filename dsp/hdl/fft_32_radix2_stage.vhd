library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;

entity fft_32_radix2_stage is
generic (
  DATA_INDEX_WIDTH  : natural;
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  STAGE_INDEX       : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_i               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_index           : in  unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Input_last            : in  std_logic;

  Output_valid          : out std_logic;
  Output_i              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_index          : out unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Output_last           : out std_logic;

  Error_input_overflow  : out std_logic
);
end entity fft_32_radix2_stage;

architecture rtl of fft_32_radix2_stage is

  constant BUFFER_DATA_WIDTH  : natural := 2*INPUT_DATA_WIDTH;
  constant TWIDDLE_DATA_WIDTH : natural := 17;

  constant DATA_CYCLES            : natural := 32;
  constant READ_INDEX_A_S8        : natural_array_t(0 to DATA_CYCLES-1) := (0, 1, 2, 3,   0, 1, 2, 3,   8, 9, 10, 11,     8, 9, 10, 11,       16, 17, 18, 19,   16, 17, 18, 19,   24, 25, 26, 27,   24, 25, 26, 27);
  constant READ_INDEX_B_S8        : natural_array_t(0 to DATA_CYCLES-1) := (4, 5, 6, 7,   4, 5, 6, 7,   12, 13, 14, 15,   12, 13, 14, 15,     20, 21, 22, 23,   20, 21, 22, 23,   28, 29, 30, 31,   28, 29, 30, 31);
  constant READ_INDEX_A_S16       : natural_array_t(0 to DATA_CYCLES-1) := (0, 1, 2,  3,  4,  5,  6,  7,    0, 1, 2,  3,  4,  5,  6,  7,      16, 17, 18, 19, 20, 21, 22, 23,   16, 17, 18, 19, 20, 21, 22, 23);
  constant READ_INDEX_B_S16       : natural_array_t(0 to DATA_CYCLES-1) := (8, 9, 10, 11, 12, 13, 14, 15,   8, 9, 10, 11, 12, 13, 14, 15,     24, 25, 26, 27, 28, 29, 30, 31,   24, 25, 26, 27, 28, 29, 30, 31);
  constant READ_INDEX_A_S32       : natural_array_t(0 to DATA_CYCLES-1) := (0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15);
  constant READ_INDEX_B_S32       : natural_array_t(0 to DATA_CYCLES-1) := (16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,   16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31);

  signal w_buf_wr_data            : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_addr            : unsigned_array_t(1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_buf_rd_data            : std_logic_vector_array_t(1 downto 0)(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_i          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_q          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_twiddle_fac_c          : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal w_twiddle_fac_c_plus_d   : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal w_twiddle_fac_d_minus_c  : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r_calc_active            : std_logic;
  signal r_calc_index             : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_calc_active_pipe       : std_logic_vector(1 downto 0);
  signal r_calc_index_pipe        : unsigned_array_t(1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_calc_index_last        : std_logic;

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32))
    report "Invalid stage index"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_calc_active <= '0';
        r_calc_index  <= (others => '-');
      else
        if ((Input_valid = '1') and (Input_last = '1')) then
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

  w_buf_wr_data <= std_logic_vector(Input_i) & std_logic_vector(Input_q);

  process(all)
  begin
    if (STAGE_INDEX = 8) then
      w_buf_rd_addr(0) <= to_unsigned(READ_INDEX_A_S8(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= to_unsigned(READ_INDEX_B_S8(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
    elsif (STAGE_INDEX = 16) then
      w_buf_rd_addr(0) <= to_unsigned(READ_INDEX_A_S16(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= to_unsigned(READ_INDEX_B_S16(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
    else
      w_buf_rd_addr(0) <= to_unsigned(READ_INDEX_A_S32(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= to_unsigned(READ_INDEX_B_S32(to_integer(r_calc_index)), DATA_INDEX_WIDTH);
    end if;
  end process;

  g_buffer : for i in 0 to 1 generate
    i_buffer : entity mem_lib.ram_sdp
    generic map (
      ADDR_WIDTH  => DATA_INDEX_WIDTH,
      DATA_WIDTH  => BUFFER_DATA_WIDTH,
      LATENCY     => 2
    )
    port map (
      Clk       => Clk,

      Wr_en     => Input_valid,
      Wr_addr   => Input_index,
      Wr_data   => w_buf_wr_data,

      Rd_en     => '1',
      Rd_reg_ce => '1',
      Rd_addr   => w_buf_rd_addr(i),
      Rd_data   => w_buf_rd_data(i)
    );

    w_buf_rd_data_i(i) <= signed(w_buf_rd_data(i)(BUFFER_DATA_WIDTH - 1 downto (BUFFER_DATA_WIDTH - INPUT_DATA_WIDTH)));
    w_buf_rd_data_q(i) <= signed(w_buf_rd_data(i)(INPUT_DATA_WIDTH - 1 downto 0));
  end generate g_buffer;

  i_twiddle_mem : entity dsp_lib.fft_32_twiddle_mem
  generic map (
    STAGE_INDEX => STAGE_INDEX,
    DATA_WIDTH  => TWIDDLE_DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk                 => Clk,

    Read_index          => r_calc_index,
    Read_data_c         => w_twiddle_fac_c,
    Read_data_c_plus_d  => w_twiddle_fac_c_plus_d,
    Read_data_d_minus_c => w_twiddle_fac_d_minus_c
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_calc_active_pipe <= r_calc_active_pipe(0) & r_calc_active;
      r_calc_index_pipe  <= r_calc_index_pipe(0)  & r_calc_index;
    end if;
  end process;

  w_calc_index_last <= to_stdlogic(r_calc_index_pipe(1) = (DATA_CYCLES - 1));

  i_radix2_output : entity dsp_lib.fft_radix2_output
  generic map (
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    TWIDDLE_DATA_WIDTH  => TWIDDLE_DATA_WIDTH,
    DATA_INDEX_WIDTH    => DATA_INDEX_WIDTH,
    LATENCY             => 3
  )
  port map (
    Clk                     => Clk,

    Input_valid             => r_calc_active_pipe(1),
    Input_i                 => w_buf_rd_data_i,
    Input_q                 => w_buf_rd_data_q,
    Input_twiddle_c         => w_twiddle_fac_c,
    Input_twiddle_c_plus_d  => w_twiddle_fac_c_plus_d,
    Input_twiddle_d_minus_c => w_twiddle_fac_d_minus_c,
    Input_index             => r_calc_index_pipe(1),
    Input_last              => w_calc_index_last,

    Output_valid            => Output_valid,
    Output_i                => Output_i,
    Output_q                => Output_q,
    Output_index            => Output_index, --TODO: add tag
    Output_last             => Output_last
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= Input_valid and r_calc_active and to_stdlogic(r_calc_index /= (2**DATA_INDEX_WIDTH - 1));
    end if;
  end process;

end architecture rtl;
