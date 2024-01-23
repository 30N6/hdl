library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_32 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural
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
end entity fft_32;

architecture rtl of fft_32 is

  constant NUM_CYCLES              : natural := 32;
  constant NUM_PAGES                : natural := 2;
  constant PAGE_INDEX_WIDTH         : natural := clog2(NUM_PAGES);

  constant INPUT_BUFFER_ADDR_WIDTH  : natural := FFT32_DATA_INDEX_WIDTH + PAGE_INDEX_WIDTH;
  constant INPUT_MEM_DATA_WIDTH     : natural := 2*INPUT_DATA_WIDTH;
  constant INPUT_MEM_INFO_WIDTH     : natural := FFT_TAG_WIDTH + 1;

  constant FFT4_OUTPUT_WIDTH        : natural := INPUT_DATA_WIDTH + 2;
  constant FFT8_OUTPUT_WIDTH        : natural := FFT4_OUTPUT_WIDTH + 1;
  constant FFT16_OUTPUT_WIDTH       : natural := FFT8_OUTPUT_WIDTH + 1;
  constant FFT32_OUTPUT_WIDTH       : natural := FFT16_OUTPUT_WIDTH + 1;

  constant NUM_INPUT_PIPE_STAGES    : natural := 1;
  constant INPUT_READ_INDEX         : natural_array_t(0 to NUM_CYCLES-1) := (0, 8, 16, 24,   4, 12, 20, 28,    2, 10, 18, 26,    6, 14, 22, 30,    1, 9, 17, 25,   5, 13, 21, 29,    3, 11, 19, 27,    7, 15, 23, 31);

  signal r_rst                  : std_logic;

  signal r_input_wr_control     : fft_control_t;
  signal r_input_wr_data        : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);
  signal w_input_wr_info        : std_logic_vector(INPUT_MEM_INFO_WIDTH - 1 downto 0);
  signal w_input_wr_addr        : unsigned(INPUT_BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_input_wr_valid_last  : std_logic;

  signal w_input_rd_addr        : unsigned(INPUT_BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_input_rd_data        : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);
  signal w_input_rd_info        : std_logic_vector(INPUT_MEM_INFO_WIDTH - 1 downto 0);

  signal r_write_page_index     : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index      : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_input_active         : std_logic;
  signal r_input_index          : unsigned(FFT32_DATA_INDEX_WIDTH - 1 downto 0);

  signal r_input_index_pipe     : unsigned_array_t(NUM_INPUT_PIPE_STAGES - 1 downto 0)(FFT32_DATA_INDEX_WIDTH - 1 downto 0);
  signal r_input_active_pipe    : std_logic_vector(NUM_INPUT_PIPE_STAGES - 1 downto 0);
  signal r_input_last_pipe      : std_logic_vector(NUM_INPUT_PIPE_STAGES - 1 downto 0);

  signal r_fft4_inpput_control  : fft_control_t;
  signal r_fft4_input_i         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_q         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_fft4_output_control  : fft_control_t;
  signal w_fft4_output_i        : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_q        : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft4_serial_control  : fft_control_t;
  signal w_fft4_serial_i        : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_serial_q        : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft8_output_control  : fft_control_t;
  signal w_fft8_output_i        : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft8_output_q        : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft16_output_control : fft_control_t;
  signal w_fft16_output_i       : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft16_output_q       : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft32_output_control : fft_control_t;
  signal w_fft32_output_i       : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft32_output_q       : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_wr_control <= Input_control;
      r_input_wr_data    <= std_logic_vector(Input_i) & std_logic_vector(Input_q);
    end if;
  end process;

  w_input_wr_info       <= r_input_wr_control.reverse & r_input_wr_control.tag;
  w_input_wr_valid_last <= r_input_wr_control.valid and r_input_wr_control.last;
  w_input_wr_addr       <= r_write_page_index & r_input_wr_control.data_index(FFT32_DATA_INDEX_WIDTH - 1 downto 0);
  w_input_rd_addr       <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX(to_integer(r_input_index)), FFT32_DATA_INDEX_WIDTH);

  i_data_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => INPUT_BUFFER_ADDR_WIDTH,
    DATA_WIDTH  => INPUT_MEM_DATA_WIDTH,
    LATENCY     => NUM_INPUT_PIPE_STAGES
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_input_wr_control.valid,
    Wr_addr   => w_input_wr_addr,
    Wr_data   => r_input_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_input_rd_addr,
    Rd_data   => w_input_rd_data
  );

  i_info_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => PAGE_INDEX_WIDTH,
    DATA_WIDTH  => INPUT_MEM_INFO_WIDTH,
    LATENCY     => NUM_INPUT_PIPE_STAGES
  )
  port map (
    Clk       => Clk,

    Wr_en     => w_input_wr_valid_last,
    Wr_addr   => r_write_page_index,
    Wr_data   => w_input_wr_info,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => r_read_page_index,
    Rd_data   => w_input_rd_info
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_input_index       <= (others => '0');
        r_input_active      <= '0';
        r_write_page_index  <= (others => '0');
        r_read_page_index   <= (others => '0');
      else
        if (w_input_wr_valid_last = '1') then
          r_input_active      <= '1';
          r_input_index       <= (others => '0');
          r_write_page_index  <= r_write_page_index + 1;
          r_read_page_index   <= r_write_page_index;
        else
          if (r_input_index = (NUM_CYCLES - 1)) then
            r_input_active <= '0';
          end if;
          r_input_index <= r_input_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (NUM_INPUT_PIPE_STAGES > 1) then
        r_input_index_pipe      <= r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)   & r_input_index;
        r_input_active_pipe     <= r_input_active_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)  & r_input_active;
        r_input_last_pipe       <= r_input_last_pipe(NUM_INPUT_PIPE_STAGES - 2 downto 0)    & to_stdlogic(r_input_index = (NUM_CYCLES-1));
      else
        r_input_index_pipe(0)   <=  r_input_index;
        r_input_active_pipe(0)  <=  r_input_active;
        r_input_last_pipe(0)    <=  to_stdlogic(r_input_index = (NUM_CYCLES-1));
      end if;
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

      r_fft4_inpput_control.valid       <= r_input_active_pipe(NUM_INPUT_PIPE_STAGES - 1) and to_stdlogic(r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 1)(1 downto 0) = 3);
      r_fft4_inpput_control.last        <= r_input_last_pipe(NUM_INPUT_PIPE_STAGES - 1);
      r_fft4_inpput_control.reverse     <= w_input_rd_info(FFT_TAG_WIDTH);
      r_fft4_inpput_control.data_index  <= resize_up(r_input_index_pipe(NUM_INPUT_PIPE_STAGES - 1)(FFT32_DATA_INDEX_WIDTH - 1 downto 2) & "00", r_fft4_inpput_control.data_index'length);
      r_fft4_inpput_control.tag         <= w_input_rd_info(FFT_TAG_WIDTH - 1 downto 0);
    end if;
  end process;

  i_fft_4_calc : entity dsp_lib.fft_4
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH,
    LATENCY           => 2
  )
  port map (
    Clk             => Clk,

    Input_control   => r_fft4_inpput_control,
    Input_i         => r_fft4_input_i,
    Input_q         => r_fft4_input_q,

    Output_control  => w_fft4_output_control,
    Output_i        => w_fft4_output_i,
    Output_q        => w_fft4_output_q
  );

  i_ff4_serializer : entity dsp_lib.fft_4_serializer
  generic map (
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_control         => w_fft4_output_control,
    Input_i               => w_fft4_output_i,
    Input_q               => w_fft4_output_q,

    Output_control        => w_fft4_serial_control,
    Output_i              => w_fft4_serial_i,
    Output_q              => w_fft4_serial_q
  );

  i_fft_8 : entity dsp_lib.fft_radix2_stage
  generic map (
    NUM_CYCLES        => NUM_CYCLES,
    CYCLE_INDEX_WIDTH => FFT32_DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT8_OUTPUT_WIDTH,
    STAGE_INDEX       => 8,
    FINAL_STAGE       => false
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_control         => w_fft4_serial_control,
    Input_i               => w_fft4_serial_i,
    Input_q               => w_fft4_serial_q,

    Output_control        => w_fft8_output_control,
    Output_i              => w_fft8_output_i,
    Output_q              => w_fft8_output_q
  );

  i_fft_16 : entity dsp_lib.fft_radix2_stage
  generic map (
    NUM_CYCLES        => NUM_CYCLES,
    CYCLE_INDEX_WIDTH => FFT32_DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT8_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT16_OUTPUT_WIDTH,
    STAGE_INDEX       => 16,
    FINAL_STAGE       => false
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_control         => w_fft8_output_control,
    Input_i               => w_fft8_output_i,
    Input_q               => w_fft8_output_q,

    Output_control        => w_fft16_output_control,
    Output_i              => w_fft16_output_i,
    Output_q              => w_fft16_output_q
  );

  i_fft_32 : entity dsp_lib.fft_radix2_stage
  generic map (
    NUM_CYCLES        => NUM_CYCLES,
    CYCLE_INDEX_WIDTH => FFT32_DATA_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT16_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT32_OUTPUT_WIDTH,
    STAGE_INDEX       => 32,
    FINAL_STAGE       => true
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_control         => w_fft16_output_control,
    Input_i               => w_fft16_output_i,
    Input_q               => w_fft16_output_q,

    Output_control        => w_fft32_output_control,
    Output_i              => w_fft32_output_i,
    Output_q              => w_fft32_output_q
  );

  Output_control  <= w_fft32_output_control;
  Output_i        <= w_fft32_output_i(FFT32_OUTPUT_WIDTH - 1 downto (FFT32_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  Output_q        <= w_fft32_output_q(FFT32_OUTPUT_WIDTH - 1 downto (FFT32_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));

end architecture rtl;
