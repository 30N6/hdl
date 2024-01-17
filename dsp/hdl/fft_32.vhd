library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

  --TODO: 12 bit ADC data

entity fft_32 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  IFFT_MODE         : boolean
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_i               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_index           : in  unsigned(4 downto 0);
  Input_last            : in  std_logic;

  Output_valid          : out std_logic;
  Output_i              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_index          : out unsigned(4 downto 0);
  Output_last           : out std_logic;

  Error_input_overflow  : out std_logic --TODO: use
);
end entity fft_32;

architecture rtl of fft_32 is

  constant DATA_CYCLES            : natural := 32;
  constant DATA_INDEX_WIDTH       : natural := clog2(DATA_CYCLES);

  constant INPUT_MEM_DATA_WIDTH   : natural := 2*INPUT_DATA_WIDTH;

  constant FFT4_OUTPUT_WIDTH      : natural := INPUT_DATA_WIDTH + 2;
  constant FFT8_OUTPUT_WIDTH      : natural := FFT4_OUTPUT_WIDTH + 1;
  constant FFT16_OUTPUT_WIDTH     : natural := FFT8_OUTPUT_WIDTH + 1;
  constant FFT32_OUTPUT_WIDTH     : natural := FFT16_OUTPUT_WIDTH + 1;

  constant NUM_INPUT_PIPE_STAGES  : natural := 2;
  constant INPUT_READ_INDEX       : natural_array_t(0 to DATA_CYCLES-1) := (0, 8, 16, 24,   4, 12, 20, 28,    2, 10, 18, 26,    6, 14, 22, 30,    1, 9, 17, 25,   5, 13, 21, 29,    3, 11, 19, 27,    7, 15, 23, 31);

  signal r_rst                  : std_logic;

  signal r_input_wr_valid       : std_logic;
  signal r_input_wr_addr        : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_input_wr_data        : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);
  signal r_input_wr_last        : std_logic;

  signal w_input_rd_addr        : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_input_rd_data        : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);

  signal r_input_active         : std_logic;
  signal r_input_index          : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal r_input_index_pipe     : unsigned_array_t(NUM_INPUT_PIPE_STAGES - 1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_input_active_pipe    : std_logic_vector(NUM_INPUT_PIPE_STAGES - 1 downto 0);
  signal r_input_last_pipe      : std_logic_vector(NUM_INPUT_PIPE_STAGES - 1 downto 0);

  signal r_fft4_input_valid     : std_logic;
  signal r_fft4_input_i         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_q         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_index     : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_fft4_input_last      : std_logic;

  signal w_fft4_output_valid    : std_logic;
  signal w_fft4_output_i        : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_q        : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_index    : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_fft4_output_last     : std_logic;

  signal w_fft4_serial_valid    : std_logic;
  signal w_fft4_serial_i        : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_serial_q        : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_serial_index    : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_fft4_serial_last     : std_logic;

  signal w_fft8_output_valid    : std_logic;
  signal w_fft8_output_i        : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft8_output_q        : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft8_output_index    : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_fft8_output_last     : std_logic;

  signal w_fft16_output_valid   : std_logic;
  signal w_fft16_output_i       : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft16_output_q       : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft16_output_index   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_fft16_output_last    : std_logic;

  signal w_fft32_output_valid   : std_logic;
  signal w_fft32_output_i       : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft32_output_q       : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft32_output_index   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_fft32_output_last    : std_logic;

  signal w_fft_error_overflow   : std_logic_vector(4 downto 0);
  signal r_fft_error_overflow   : std_logic_vector(4 downto 0);

begin

  assert (IFFT_MODE = false)
    report "TODO"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_wr_valid  <= Input_valid;
      r_input_wr_addr   <= Input_index;
      r_input_wr_data   <= std_logic_vector(Input_i) & std_logic_vector(Input_q);
      r_input_wr_last   <= Input_last;
    end if;
  end process;

  w_input_rd_addr <= to_unsigned(INPUT_READ_INDEX(to_integer(r_input_index)), DATA_INDEX_WIDTH);

  i_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => DATA_INDEX_WIDTH,
    DATA_WIDTH  => INPUT_MEM_DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_input_wr_valid,
    Wr_addr   => r_input_wr_addr,
    Wr_data   => r_input_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_input_rd_addr,
    Rd_data   => w_input_rd_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_input_index   <= (others => '0');
        r_input_active  <= '0';
      else
        if ((r_input_wr_valid = '1') and (r_input_wr_last = '1')) then
          r_input_active  <= '1';
          r_input_index   <= (others => '0');
        else
          if (r_input_index = (DATA_CYCLES - 1)) then
            r_input_active <= '0';
          end if;
          r_input_index <= r_input_index + 1;
        end if;
      end if;
    end if;
  end process;

  w_fft_error_overflow(0) <= r_input_wr_valid and r_input_active and to_stdlogic(r_input_index /= (DATA_CYCLES - 1));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_index_pipe  <= r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)   & r_input_index;
      r_input_active_pipe <= r_input_active_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)  & r_input_active;
      r_input_last_pipe   <= r_input_last_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)    & to_stdlogic(r_input_index = (DATA_CYCLES-1));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_input_active_pipe(NUM_INPUT_PIPE_STAGES - 1) = '1') then
        for i in 0 to 3 loop
          if (r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 1)(1 downto 0) = i) then

            r_fft4_input_i(i) <= signed(w_input_rd_data(INPUT_MEM_DATA_WIDTH - 1 downto (INPUT_MEM_DATA_WIDTH - INPUT_DATA_WIDTH)));
            r_fft4_input_q(i) <= signed(w_input_rd_data(INPUT_DATA_WIDTH - 1 downto 0));
          end if;
        end loop;
      end if;

      r_fft4_input_valid  <= r_input_active_pipe(NUM_INPUT_PIPE_STAGES - 1) and to_stdlogic(r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 1)(1 downto 0) = 3);
      r_fft4_input_index  <= r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 1)(DATA_INDEX_WIDTH - 1 downto 2) & "00";
      r_fft4_input_last   <= r_input_last_pipe(NUM_INPUT_PIPE_STAGES - 1);
    end if;
  end process;

  i_fft_4_calc : entity dsp_lib.fft_4
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH,
    DATA_INDEX_WIDTH  => DATA_INDEX_WIDTH,
    LATENCY           => 0
  )
  port map (
    Clk               => Clk,

    --TODO: fft control struct: valid, index, last, tag
    Input_valid       => r_fft4_input_valid,
    Input_i           => r_fft4_input_i,
    Input_q           => r_fft4_input_q,
    Input_index       => r_fft4_input_index,
    Input_last        => r_fft4_input_last,

    Output_valid      => w_fft4_output_valid,
    Output_i          => w_fft4_output_i,
    Output_q          => w_fft4_output_q,
    Output_index      => w_fft4_output_index,
    Output_last       => w_fft4_output_last
  );

  i_ff4_serializer : entity dsp_lib.fft_4_serializer
  generic map (
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH,
    DATA_INDEX_WIDTH  => DATA_INDEX_WIDTH
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_fft4_output_valid,
    Input_i               => w_fft4_output_i,
    Input_q               => w_fft4_output_q,
    Input_index           => w_fft4_output_index,
    Input_last            => w_fft4_output_last,

    Output_valid          => w_fft4_serial_valid,
    Output_i              => w_fft4_serial_i,
    Output_q              => w_fft4_serial_q,
    Output_index          => w_fft4_serial_index,
    Output_last           => w_fft4_serial_last,

    Error_input_overflow  => w_fft_error_overflow(1)
  );

  i_fft_8 : entity dsp_lib.fft_32_radix2_stage
  generic map (
    DATA_INDEX_WIDTH  => DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT8_OUTPUT_WIDTH,
    STAGE_INDEX       => 8
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_fft4_serial_valid,
    Input_i               => w_fft4_serial_i,
    Input_q               => w_fft4_serial_q,
    Input_index           => w_fft4_serial_index,
    Input_last            => w_fft4_serial_last,

    Output_valid          => w_fft8_output_valid,
    Output_i              => w_fft8_output_i,
    Output_q              => w_fft8_output_q,
    Output_index          => w_fft8_output_index,
    Output_last           => w_fft8_output_last,

    Error_input_overflow  => w_fft_error_overflow(2)
  );

  i_fft_16 : entity dsp_lib.fft_32_radix2_stage
  generic map (
    DATA_INDEX_WIDTH  => DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT8_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT16_OUTPUT_WIDTH,
    STAGE_INDEX       => 16
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_fft8_output_valid,
    Input_i               => w_fft8_output_i,
    Input_q               => w_fft8_output_q,
    Input_index           => w_fft8_output_index,
    Input_last            => w_fft8_output_last,

    Output_valid          => w_fft16_output_valid,
    Output_i              => w_fft16_output_i,
    Output_q              => w_fft16_output_q,
    Output_index          => w_fft16_output_index,
    Output_last           => w_fft16_output_last,

    Error_input_overflow  => w_fft_error_overflow(3)
  );

  i_fft_32 : entity dsp_lib.fft_32_radix2_stage
  generic map (
    DATA_INDEX_WIDTH  => DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT16_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT32_OUTPUT_WIDTH,
    STAGE_INDEX       => 32
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_fft16_output_valid,
    Input_i               => w_fft16_output_i,
    Input_q               => w_fft16_output_q,
    Input_index           => w_fft16_output_index,
    Input_last            => w_fft16_output_last,

    Output_valid          => w_fft32_output_valid,
    Output_i              => w_fft32_output_i,
    Output_q              => w_fft32_output_q,
    Output_index          => w_fft32_output_index,
    Output_last           => w_fft32_output_last,

    Error_input_overflow  => w_fft_error_overflow(4)
  );

  Output_valid <= w_fft32_output_valid;
  Output_i     <= w_fft32_output_i; --TODO: trim
  Output_q     <= w_fft32_output_q; --TODO: trim
  Output_index <= w_fft32_output_index;
  Output_last  <= w_fft32_output_last;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fft_error_overflow <= w_fft_error_overflow;
      Error_input_overflow <= or_reduce(r_fft_error_overflow);
    end if;
  end process;

end architecture rtl;
