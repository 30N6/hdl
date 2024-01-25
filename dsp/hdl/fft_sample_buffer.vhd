library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity fft_sample_buffer is
generic (
  DATA_WIDTH        : natural;
  DATA_INDEX_WIDTH  : natural;
  READ_PIPE_STAGES  : natural;
  IMMEDIATE_READ    : boolean
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_last    : in  std_logic;
  Input_index   : in  unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Input_data    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

  Output_start  : in  std_logic;
  Output_valid  : out std_logic;
  Output_last   : out std_logic;
  Output_index  : out unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Output_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
);
end entity fft_sample_buffer;

architecture rtl of fft_sample_buffer is

  constant NUM_PAGES          : natural := 2;
  constant PAGE_INDEX_WIDTH   : natural := clog2(NUM_PAGES);

  constant BUFFER_ADDR_WIDTH  : natural := DATA_INDEX_WIDTH + PAGE_INDEX_WIDTH;

  signal r_write_page_index   : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index    : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_input_active       : std_logic;
  signal r_input_index        : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal w_buf_wr_addr        : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_buf_rd_addr        : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);

  signal r_output_index_pipe  : unsigned_array_t(READ_PIPE_STAGES - 1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_output_active_pipe : std_logic_vector(READ_PIPE_STAGES - 1 downto 0);
  signal r_output_last_pipe   : std_logic_vector(READ_PIPE_STAGES - 1 downto 0);

begin

  w_buf_wr_addr <= r_write_page_index & Input_index;
  w_buf_rd_addr <= r_read_page_index  & r_input_index;

  i_data_buffer : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => BUFFER_ADDR_WIDTH,
    DATA_WIDTH  => DATA_WIDTH,
    LATENCY     => READ_PIPE_STAGES
  )
  port map (
    Clk       => Clk,

    Wr_en     => Input_valid,
    Wr_addr   => w_buf_wr_addr,
    Wr_data   => Input_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_buf_rd_addr,
    Rd_data   => Output_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_write_page_index <= (others => '0');
      else
        if ((Input_valid = '1') and (Input_last = '1')) then
          r_write_page_index <= r_write_page_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_input_index     <= (others => '0');
        r_input_active    <= '0';
        r_read_page_index <= (others => '0');
      else
        if ((IMMEDIATE_READ and (Input_valid = '1') and (Input_last = '1')) or (not(IMMEDIATE_READ) and (Output_start = '1'))) then
          r_input_active      <= '1';
          r_input_index       <= (others => '0');
        elsif (r_input_active = '1') then
          if (r_input_index = (2**DATA_INDEX_WIDTH - 1)) then
            r_read_page_index <= r_read_page_index + 1;
            r_input_active    <= '0';
          else
            r_input_index     <= r_input_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (READ_PIPE_STAGES > 1) then
        r_output_index_pipe      <= r_output_index_pipe(READ_PIPE_STAGES - 2 downto 0)   & r_input_index;
        r_output_active_pipe     <= r_output_active_pipe(READ_PIPE_STAGES - 2 downto 0)  & r_input_active;
        r_output_last_pipe       <= r_output_last_pipe(READ_PIPE_STAGES - 2 downto 0)    & to_stdlogic(r_input_index = (2**DATA_INDEX_WIDTH - 1));
      else
        r_output_index_pipe(0)   <=  r_input_index;
        r_output_active_pipe(0)  <=  r_input_active;
        r_output_last_pipe(0)    <=  to_stdlogic(r_input_index = (2**DATA_INDEX_WIDTH - 1));
      end if;
    end if;
  end process;

  Output_valid  <= r_output_active_pipe(READ_PIPE_STAGES - 1);
  Output_last   <= r_output_last_pipe(READ_PIPE_STAGES - 1);
  Output_index  <= r_output_index_pipe(READ_PIPE_STAGES - 1);

end architecture rtl;
