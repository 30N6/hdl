library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_32_radix2_stage is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  STAGE_INDEX       : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_control         : in  fft32_control_t;
  Input_i               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control        : out fft32_control_t;
  Output_i              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
end entity fft_32_radix2_stage;

architecture rtl of fft_32_radix2_stage is

  constant BUFFER_DATA_WIDTH    : natural := 2*INPUT_DATA_WIDTH;
  constant TWIDDLE_DATA_WIDTH   : natural := 17;
  constant TWIDDLE_FRAC_WIDTH   : natural := 16;
  constant MEM_READ_LATENCY     : natural := 2;
  constant OUTPUT_STAGE_LATENCY : natural := 3;
  constant OUTPUT_PIPE_DEPTH    : natural := MEM_READ_LATENCY + OUTPUT_STAGE_LATENCY;
  constant NUM_PAGES            : natural := 2;
  constant PAGE_INDEX_WIDTH     : natural := clog2(NUM_PAGES);
  constant MEM_ADDR_WIDTH       : natural := PAGE_INDEX_WIDTH + FFT32_DATA_INDEX_WIDTH;

  constant DATA_CYCLES            : natural := 32;
  constant READ_INDEX_A_S8        : natural_array_t(0 to DATA_CYCLES-1) := (0, 1, 2, 3,   0, 1, 2, 3,   8, 9, 10, 11,     8, 9, 10, 11,       16, 17, 18, 19,   16, 17, 18, 19,   24, 25, 26, 27,   24, 25, 26, 27);
  constant READ_INDEX_B_S8        : natural_array_t(0 to DATA_CYCLES-1) := (4, 5, 6, 7,   4, 5, 6, 7,   12, 13, 14, 15,   12, 13, 14, 15,     20, 21, 22, 23,   20, 21, 22, 23,   28, 29, 30, 31,   28, 29, 30, 31);
  constant READ_INDEX_A_S16       : natural_array_t(0 to DATA_CYCLES-1) := (0, 1, 2,  3,  4,  5,  6,  7,    0, 1, 2,  3,  4,  5,  6,  7,      16, 17, 18, 19, 20, 21, 22, 23,   16, 17, 18, 19, 20, 21, 22, 23);
  constant READ_INDEX_B_S16       : natural_array_t(0 to DATA_CYCLES-1) := (8, 9, 10, 11, 12, 13, 14, 15,   8, 9, 10, 11, 12, 13, 14, 15,     24, 25, 26, 27, 28, 29, 30, 31,   24, 25, 26, 27, 28, 29, 30, 31);
  constant READ_INDEX_A_S32       : natural_array_t(0 to DATA_CYCLES-1) := (0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15);
  constant READ_INDEX_B_S32       : natural_array_t(0 to DATA_CYCLES-1) := (16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,   16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31);
  constant IFFT_INDEX_MAP         : natural_array_t(0 to DATA_CYCLES-1) := (0, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);

  signal r_write_page_index       : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index        : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);

  signal w_buf_wr_addr            : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_wr_data            : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_addr            : unsigned_array_t(1 downto 0)(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_rd_data            : std_logic_vector_array_t(1 downto 0)(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_i          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_q          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_twiddle_fac_c          : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal w_twiddle_fac_c_plus_d   : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal w_twiddle_fac_d_minus_c  : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r_input_control          : fft32_control_t;
  signal r_calc_active            : std_logic;
  signal r_calc_index             : unsigned(FFT32_DATA_INDEX_WIDTH - 1 downto 0);
  signal w_read_index             : unsigned(FFT32_DATA_INDEX_WIDTH - 1 downto 0);

  signal r_calc_active_pipe       : std_logic_vector(OUTPUT_PIPE_DEPTH - 1 downto 0);
  signal r_calc_index_pipe        : unsigned_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0)(FFT32_DATA_INDEX_WIDTH - 1 downto 0);
  signal r_control_pipe           : fft32_control_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0);

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32))
    report "Invalid stage index"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((Input_control.valid = '1') and (Input_control.last = '1')) then
        r_input_control <= Input_control;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_calc_active       <= '0';
        r_calc_index        <= (others => '-');
        r_write_page_index  <= (others => '0');
        r_read_page_index   <= (others => '0');
      else
        if ((Input_control.valid = '1') and (Input_control.last = '1')) then
          r_calc_active       <= '1';
          r_calc_index        <= (others => '0');
          r_write_page_index  <= r_write_page_index + 1;
          r_read_page_index   <= r_write_page_index;
        else
          if (r_calc_index = (2**FFT32_DATA_INDEX_WIDTH - 1)) then
            r_calc_active <= '0';
          end if;
          r_calc_index <= r_calc_index + 1;
        end if;
      end if;
    end if;
  end process;

  w_buf_wr_addr <= r_write_page_index & Input_control.data_index;
  w_buf_wr_data <= std_logic_vector(Input_i) & std_logic_vector(Input_q);

  process(all)
  begin
    if ((STAGE_INDEX = 32) and (r_input_control.reverse = '1')) then
      w_read_index <= to_unsigned(IFFT_INDEX_MAP(to_integer(r_calc_index)), FFT32_DATA_INDEX_WIDTH);
    else
      w_read_index <= r_calc_index;
    end if;
  end process;

  process(all)
  begin
    if (STAGE_INDEX = 8) then
      w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S8(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S8(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
    elsif (STAGE_INDEX = 16) then
      w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S16(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S16(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
    else
      w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S32(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
      w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S32(to_integer(w_read_index)), FFT32_DATA_INDEX_WIDTH);
    end if;
  end process;

  g_buffer : for i in 0 to 1 generate
    i_buffer : entity mem_lib.ram_sdp
    generic map (
      ADDR_WIDTH  => MEM_ADDR_WIDTH,
      DATA_WIDTH  => BUFFER_DATA_WIDTH,
      LATENCY     => MEM_READ_LATENCY
    )
    port map (
      Clk       => Clk,

      Wr_en     => Input_control.valid,
      Wr_addr   => w_buf_wr_addr,
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
    LATENCY     => MEM_READ_LATENCY
  )
  port map (
    Clk                 => Clk,

    Read_index          => w_read_index,
    Read_data_c         => w_twiddle_fac_c,
    Read_data_c_plus_d  => w_twiddle_fac_c_plus_d,
    Read_data_d_minus_c => w_twiddle_fac_d_minus_c
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_calc_active_pipe <= r_calc_active_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0) & r_calc_active;
      r_calc_index_pipe  <= r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)  & r_calc_index;
      r_control_pipe     <= r_control_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)     & r_input_control;
    end if;
  end process;

  i_radix2_output : entity dsp_lib.fft_radix2_output
  generic map (
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    TWIDDLE_DATA_WIDTH  => TWIDDLE_DATA_WIDTH,
    TWIDDLE_FRAC_WIDTH  => TWIDDLE_FRAC_WIDTH,
    LATENCY             => OUTPUT_STAGE_LATENCY
  )
  port map (
    Clk                     => Clk,

    Input_i                 => w_buf_rd_data_i,
    Input_q                 => w_buf_rd_data_q,
    Input_twiddle_c         => w_twiddle_fac_c,
    Input_twiddle_c_plus_d  => w_twiddle_fac_c_plus_d,
    Input_twiddle_d_minus_c => w_twiddle_fac_d_minus_c,

    Output_i                => Output_i,
    Output_q                => Output_q
  );

  process(all)
  begin
    Output_control            <= r_control_pipe(OUTPUT_PIPE_DEPTH - 1);
    Output_control.valid      <= r_calc_active_pipe(OUTPUT_PIPE_DEPTH - 1);
    Output_control.last       <= to_stdlogic(r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1) = (DATA_CYCLES - 1));
    Output_control.data_index <= r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1);
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= '0'; --TODO  --Input_control.valid and r_calc_active and to_stdlogic(r_calc_index /= (2**FFT32_DATA_INDEX_WIDTH - 1));
    end if;
  end process;

end architecture rtl;
