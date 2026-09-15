library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_radix2_stage is
generic (
  NUM_POINTS        : natural;
  CYCLE_INDEX_WIDTH : natural;
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  STAGE_INDEX       : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Input_control   : in  fft_control_t;
  Input_i         : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q         : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control  : out fft_control_t;
  Output_i        : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q        : out signed(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity fft_radix2_stage;

architecture rtl of fft_radix2_stage is

  function get_read_index(is_a : boolean) return natural_array_t is
    variable r_a : natural_array_t(0 to NUM_POINTS - 1);
    variable r_b : natural_array_t(0 to NUM_POINTS - 1);
    variable phase : natural;
  begin
    for i in 0 to (NUM_POINTS - 1) loop
      phase := i mod STAGE_INDEX;
      if (phase < (STAGE_INDEX / 2)) then
        r_a(i) := i;
        r_b(i) := i + (STAGE_INDEX / 2);
      else
        r_a(i) := i - (STAGE_INDEX / 2);
        r_b(i) := i;
      end if;
    end loop;

    if (is_a) then
      return r_a;
    else
      return r_b;
    end if;
  end function;

  function get_ifft_index_map return natural_array_t is
    variable r : natural_array_t(0 to STAGE_INDEX - 1) := (others => 0);
  begin
    for i in 0 to (STAGE_INDEX - 1) loop
      if (i > 0) then
        r(i) := STAGE_INDEX - i;
      end if;
    end loop;
    return r;
  end function;

  constant BUFFER_DATA_WIDTH      : natural := 2*INPUT_DATA_WIDTH;
  constant TWIDDLE_DATA_WIDTH     : natural := 17;
  constant TWIDDLE_FRAC_WIDTH     : natural := 16;
  constant MEM_READ_LATENCY       : natural := 3; -- third stage to help timing into DSP block
  constant OUTPUT_STAGE_LATENCY   : natural := 8;
  constant OUTPUT_PIPE_DEPTH      : natural := MEM_READ_LATENCY + OUTPUT_STAGE_LATENCY;
  constant NUM_PAGES              : natural := 2;
  constant PAGE_INDEX_WIDTH       : natural := clog2(NUM_PAGES);
  constant MEM_ADDR_WIDTH         : natural := PAGE_INDEX_WIDTH + CYCLE_INDEX_WIDTH;

  constant READ_INDEX_A           : natural_array_t(0 to NUM_POINTS - 1) := get_read_index(true);
  constant READ_INDEX_B           : natural_array_t(0 to NUM_POINTS - 1) := get_read_index(false);
  constant IFFT_INDEX_MAP         : natural_array_t(0 to STAGE_INDEX - 1) := get_ifft_index_map;

  signal r_write_page_index       : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index        : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);

  signal w_buf_wr_addr            : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_wr_data            : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal r1_buf_rd_addr           : unsigned_array_t(1 downto 0)(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_rd_data            : std_logic_vector_array_t(1 downto 0)(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_i          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_q          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_twiddle_fac_c          : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal w_twiddle_fac_c_plus_d   : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal w_twiddle_fac_d_minus_c  : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r0_input_control         : fft_control_t;
  signal r0_calc_active           : std_logic;
  signal r0_calc_index            : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);
  signal w0_read_index            : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);

  signal r1_input_control         : fft_control_t;
  signal r1_calc_active           : std_logic;
  signal r1_calc_index            : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);
  signal r1_read_index            : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);

  signal r_calc_active_pipe       : std_logic_vector(OUTPUT_PIPE_DEPTH - 1 downto 0);
  signal r_calc_index_pipe        : unsigned_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0)(CYCLE_INDEX_WIDTH - 1 downto 0);
  signal r_control_pipe           : fft_control_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0);

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32) or (STAGE_INDEX = 64) or
          (STAGE_INDEX = 128) or (STAGE_INDEX = 256) or (STAGE_INDEX = 512) or (STAGE_INDEX = 1024))
    report "Invalid stage index"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((Input_control.valid = '1') and (Input_control.last = '1')) then
        r0_input_control <= Input_control;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r0_calc_active    <= '0';
        r0_calc_index     <= (others => '-');
        r_write_page_index  <= (others => '0');
        r_read_page_index   <= (others => '0');
      else
        if ((Input_control.valid = '1') and (Input_control.last = '1')) then
          r0_calc_active    <= '1';
          r0_calc_index     <= (others => '0');
          r_write_page_index  <= r_write_page_index + 1;
          r_read_page_index   <= r_write_page_index;
        else
          if (r0_calc_index = (2**CYCLE_INDEX_WIDTH - 1)) then
            r0_calc_active <= '0';
          end if;
          r0_calc_index <= r0_calc_index + 1;
        end if;
      end if;
    end if;
  end process;

  w_buf_wr_addr <= r_write_page_index & Input_control.data_index(CYCLE_INDEX_WIDTH - 1 downto 0);
  w_buf_wr_data <= std_logic_vector(Input_i) & std_logic_vector(Input_q);

  process(all)
  begin
    if ((NUM_POINTS = STAGE_INDEX) and (r0_input_control.reverse = '1')) then
      w0_read_index <= to_unsigned(IFFT_INDEX_MAP(to_integer(r0_calc_index)), CYCLE_INDEX_WIDTH);
    else
      w0_read_index <= r0_calc_index;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A(to_integer(w0_read_index)), CYCLE_INDEX_WIDTH);
      r1_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B(to_integer(w0_read_index)), CYCLE_INDEX_WIDTH);

      r1_input_control  <= r0_input_control;
      r1_calc_active    <= r0_calc_active;
      r1_calc_index     <= r0_calc_index;
      r1_read_index     <= w0_read_index;
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
      Rd_addr   => r1_buf_rd_addr(i),
      Rd_data   => w_buf_rd_data(i)
    );

    w_buf_rd_data_i(i) <= signed(w_buf_rd_data(i)(BUFFER_DATA_WIDTH - 1 downto (BUFFER_DATA_WIDTH - INPUT_DATA_WIDTH)));
    w_buf_rd_data_q(i) <= signed(w_buf_rd_data(i)(INPUT_DATA_WIDTH - 1 downto 0));
  end generate g_buffer;

  i_twiddle_mem : entity dsp_lib.fft_twiddle_mem
  generic map (
    NUM_POINTS        => NUM_POINTS,
    CYCLE_INDEX_WIDTH => CYCLE_INDEX_WIDTH,
    STAGE_INDEX       => STAGE_INDEX,
    DATA_WIDTH        => TWIDDLE_DATA_WIDTH,
    LATENCY           => MEM_READ_LATENCY
  )
  port map (
    Clk                 => Clk,

    Read_index          => r1_read_index,
    Read_data_c         => w_twiddle_fac_c,
    Read_data_c_plus_d  => w_twiddle_fac_c_plus_d,
    Read_data_d_minus_c => w_twiddle_fac_d_minus_c
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_calc_active_pipe <= r_calc_active_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0) & r1_calc_active;
      r_calc_index_pipe  <= r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)  & r1_calc_index;
      r_control_pipe     <= r_control_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)     & r1_input_control;
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
    Output_control.last       <= to_stdlogic(r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1) = (NUM_POINTS - 1));
    Output_control.data_index <= resize_up(r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1), Output_control.data_index'length);
  end process;

end architecture rtl;
