library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

entity fft_32 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  IFFT_MODE         : boolean
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_data_valid      : in  std_logic;
  Input_data_index      : in  unsigned(4 downto 0);
  Input_data_i          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_data_q          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_calc_start      : in  std_logic;

  Output_data_valid     : out std_logic;
  Output_data_index     : out unsigned(4 downto 0);
  Output_data_i         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_data_q         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_data_last      : out std_logic;

  Error_input_overflow  : out std_logic
);
end entity fft_32;

architecture rtl of fft_32 is

  constant DATA_INDEX_WIDTH   : natural := Input_data_index'length;
  constant S4_DATA_WIDTH      : natural := 2*INPUT_DATA_WIDTH;
  constant FFT4_OUTPUT_WIDTH  : natural := INPUT_DATA_WIDTH + 2;

  constant S1_DATA_WIDTH      : natural := 2*FFT4_OUTPUT_WIDTH;
  constant NUM_S4_READ_CYCLES : natural := 32;
  constant NUM_S4_PIPE_STAGES : natural := 3;
  constant S4_READ_INDEX      : natural_array_t(0 to NUM_S4_CYCLES-1) := (0, 8, 16, 24,   4, 12, 20, 28,    2, 10, 18, 26,    6, 14, 22, 30,    1, 9, 17, 25,   5, 13, 21, 29,    3, 11, 19, 27,    7, 15, 23, 31);

  type s0_state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_DONE
  );

  signal r_s4_wr_en     : std_logic;
  signal r_s4_wr_addr   : std_logic_vector(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_s4_wr_data   : std_logic_vector(S4_DATA_WIDTH - 1 downto 0);
  signal r_s4_start     : std_logic;

  signal w_s4_rd_addr   : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_s4_rd_data   : std_logic_vector(S4_DATA_WIDTH - 1 downto 0);

  signal w_s4_rd_index  : unsigned(clog2(NUM_S4_CYCLES) - 1 downto 0);
  signal r_s4_rd_index  : unsigned_array_t(NUM_S4_PIPE_STAGES - 1 downto 0)(clog2(NUM_S4_CYCLES) - 1 downto 0);
  signal r_s4_active    : std_logic_vector(NUM_S4_PIPE_STAGES - 1 downto 0);
  signal r_s4_done      : std_logic_vector(NUM_S4_PIPE_STAGES - 1 downto 0);
  signal s_s4_state     : std_logic;

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

  signal w_s1_rd_addr         : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal w_s1_rd_data         : std_logic_vector(S1_DATA_WIDTH - 1 downto 0);

begin

  assert (IFFT_MODE = false)
    report "TODO"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_s4_wr_en    <= Input_data_valid;
      r_s4_wr_addr  <= Input_data_index;
      r_s4_wr_data  <= std_logic_vector(Input_data_i & Input_data_q);
      r_s4_start    <= Input_calc_start;
    end if;
  end process;

  w_s4_rd_addr <= to_unsigned(S0_READ_INDEX(to_integer(r_s4_rd_index(0))), DATA_INDEX_WIDTH);

  i_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => DATA_INDEX_WIDTH,
    DATA_WIDTH  => S0_DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_s0_wr_en,
    Wr_addr   => r_s0_wr_addr,
    Wr_data   => r_s0_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_s0_rd_addr,
    Rd_data   => w_s0_rd_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_s0_state <= S_IDLE;
      else
        case s_s0_state is
        when S_IDLE =>
          if (r_s0_start = '1') then
            s_state <= S_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;
        when S_ACTIVE =>
          if (r_s0_rd_index(0) = (NUM_S0_READ_CYCLES - 1)) then
            s_state <= S_DONE;
          else
            s_state <= S_IDLE;
          end if;
        when S_DONE =>
          s_state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_IDLE) then
      w_s0_rd_index <= (others => '0');
    else
      w_s0_rd_index <= r_s0_rd_index(0) + 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_s0_rd_index <= r_s0_rd_index(NUM_S0_PIPE_STAGES - 2 downto 0) & w_s0_rd_index;
      r_s0_active   <= r_s0_active(NUM_S0_PIPE_STAGES - 2 downto 0)   & to_stdlogic(s_s0_state = S_ACTIVE);
      r_s0_done     <= r_s0_done(NUM_S0_PIPE_STAGES - 2 downto 0)     & to_stdlogic(s_s0_state = S_DONE);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_s0_active(NUM_S0_PIPE_STAGES - 1) = '1') then
        for i in 0 to 3 loop
          if (r_s0_rd_index(NUM_S0_PIPE_STAGES - 1)(1 downto 0) = i) then
            (r_fft4_input_data_i(i), r_fft4_input_data_q(i)) <= w_s0_rd_data;
          end if;
        end loop;
      end if;

      r_fft4_input_index  <= r_s0_rd_index(NUM_S0_PIPE_STAGES - 1)(clog2(NUM_S0_CYCLES) - 1 downto 2) & "00";
      r_fft4_input_valid  <= r_s0_active(NUM_S0_PIPE_STAGES - 1) and to_stdlogic(r_s0_rd_index(NUM_S0_PIPE_STAGES - 1)(1 downto 0) = 3);
    end if;
  end process;

  i_fft_4 : entity dsp_lib.fft_4
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => INPUT_DATA_WIDTH + 2,
    LATENCY           => 0
  )
  port map (
    Clk               => Clk,

    Input_data_valid  => r_fft4_input_valid,
    Input_data_i      => r_fft4_input_data_i,
    Input_data_q      => r_fft4_input_data_q,
    Input_index       => r_fft4_input_index,

    Output_data_valid => w_fft4_output_valid,
    Output_data_i     => w_fft4_output_data_i,
    Output_data_q     => w_fft4_output_data_q,
    Output_index      => w_fft4_output_index
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_fft4_output_valid = '1') then
        r_fft4_output_index  <= w_fft4_output_index;
        r_fft4_output_data_i <= w_fft4_output_data_i;
        r_fft4_output_data_q <= w_fft4_output_data_q;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_fft4_output_valid = '1') then
        r_s1_wr_en        <= '1';
        r_s1_wr_sub_index <= (others => '0');
      else
        if (r_s1_wr_sub_index = 3) then
          r_s1_wr_en      <= '0';
        end if;
        r_s1_wr_sub_index <= r_s1_wr_sub_index + 1;
      end if;
    end if;
  end process;

  w_s1_rd_addr <= r_fft4_output_index(DATA_INDEX_WIDTH - 1 downto 2) & r_s1_wr_sub_index;
  w_s1_wr_data <= (r_fft4_output_data_i(to_integer(r_s1_wr_sub_index)), r_fft4_output_data_q(to_integer(r_s1_wr_sub_index)));

  i_buffer_s1 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => DATA_INDEX_WIDTH,
    DATA_WIDTH  => S1_DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_s1_wr_en,
    Wr_addr   => w_s1_rd_addr,
    Wr_data   => w_s1_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_s1_rd_addr(i),
    Rd_data   => w_s1_rd_data(i)
  );

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

    Input_data_valid      : in  std_logic;
    Input_data_last       : in  std_logic;
    Input_data_index      : in  unsigned(DATA_INDEX_WIDTH - 1 downto 0);
    Input_data_i          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
    Input_data_q          : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

    Output_data_valid     : out std_logic;
    Output_data_index     : out unsigned(DATA_INDEX_WIDTH - 1 downto 0);
    Output_data_i         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
    Output_data_q         : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);

    Error_input_overflow  : out std_logic
  );


end architecture rtl;
