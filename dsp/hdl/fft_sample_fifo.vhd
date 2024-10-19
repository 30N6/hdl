library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity fft_sample_fifo is
generic (
  DATA_WIDTH        : natural;
  DATA_INDEX_WIDTH  : natural;
  READ_LATENCY      : natural;
  IMMEDIATE_READ    : std_logic
);
port (
  Clk               : in  std_logic;
  Rst               : in  std_logic;

  Input_ctrl        : in  fft_control_t;
  Input_data        : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_read       : in  std_logic;
  Output_available  : out std_logic;
  Output_ctrl       : out fft_control_t;
  Output_data       : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Error_overflow  : out std_logic;
  Error_underflow : out std_logic
);
end entity fft_sample_fifo;

architecture rtl of fft_sample_fifo is

  constant NUM_PAGES          : natural := 2;
  constant PAGE_INDEX_WIDTH   : natural := clog2(NUM_PAGES);
  constant BUFFER_ADDR_WIDTH  : natural := DATA_INDEX_WIDTH + clog2(NUM_PAGES);
  constant BUFFER_DATA_WIDTH  : natural := 2*DATA_WIDTH;

  signal w_input_last_valid   : std_logic;

  signal r_write_page_index   : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index    : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);

  signal w_buf_write_data     : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_write_addr     : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);

  signal w_buf_read_data      : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_read_addr      : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);

  signal r_read_active        : std_logic;
  signal r_read_index         : unsigned(DATA_INDEX_WIDTH - 1 downto 0);

  signal r_output_index_pipe  : unsigned_array_t(READ_LATENCY - 1 downto 0)(DATA_INDEX_WIDTH - 1 downto 0);
  signal r_output_active_pipe : std_logic_vector(READ_LATENCY - 1 downto 0);
  signal r_output_last_pipe   : std_logic_vector(READ_LATENCY - 1 downto 0);

  signal w_output_available   : std_logic;

begin

  w_buf_write_data  <= std_logic_vector(Input_data(1)) & std_logic_vector(Input_data(0));
  w_buf_write_addr  <= r_write_page_index & Input_ctrl.data_index(DATA_INDEX_WIDTH - 1 downto 0);
  w_buf_read_addr   <= r_read_page_index  & r_read_index;

  i_data_buffer : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => BUFFER_ADDR_WIDTH,
    DATA_WIDTH  => BUFFER_DATA_WIDTH,
    LATENCY     => READ_LATENCY
  )
  port map (
    Clk       => Clk,

    Wr_en     => Input_ctrl.valid,
    Wr_addr   => w_buf_write_addr,
    Wr_data   => w_buf_write_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_buf_read_addr,
    Rd_data   => w_buf_read_data
  );

  Output_data(0) <= signed(w_buf_read_data(DATA_WIDTH - 1 downto 0));
  Output_data(1) <= signed(w_buf_read_data(BUFFER_DATA_WIDTH - 1 downto DATA_WIDTH));

  w_input_last_valid <= Input_ctrl.valid and Input_ctrl.last;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_write_page_index <= (others => '0');
      else
        if (w_input_last_valid = '1') then
          r_write_page_index <= r_write_page_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_index      <= (others => '0');
        r_read_active     <= '0';
        r_read_page_index <= (others => '0');
      else
        if (r_read_active = '0') then
          r_read_active   <= (IMMEDIATE_READ and w_input_last_valid) or (not(IMMEDIATE_READ) and Output_read);
          r_read_index    <= (others => '0');
        else
          if (r_read_index = (2**DATA_INDEX_WIDTH - 1)) then
            r_read_page_index <= r_read_page_index + 1;
            r_read_active     <= '0';
          else
            r_read_index      <= r_read_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  w_output_available <= to_stdlogic(r_write_page_index /= r_read_page_index);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (READ_LATENCY > 1) then
        r_output_index_pipe      <= r_output_index_pipe(READ_LATENCY - 2 downto 0)   & r_read_index;
        r_output_active_pipe     <= r_output_active_pipe(READ_LATENCY - 2 downto 0)  & r_read_active;
        r_output_last_pipe       <= r_output_last_pipe(READ_LATENCY - 2 downto 0)    & to_stdlogic(r_read_index = (2**DATA_INDEX_WIDTH - 1));
      else
        r_output_index_pipe(0)   <=  r_read_index;
        r_output_active_pipe(0)  <=  r_read_active;
        r_output_last_pipe(0)    <=  to_stdlogic(r_read_index = (2**DATA_INDEX_WIDTH - 1));
      end if;
    end if;
  end process;

  Output_ctrl.valid       <= r_output_active_pipe(READ_LATENCY - 1);
  Output_ctrl.last        <= r_output_last_pipe(READ_LATENCY - 1);
  Output_ctrl.data_index  <= resize_up(r_output_index_pipe(READ_LATENCY - 1), Output_ctrl.data_index'length);

  Output_available <= w_output_available;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_overflow  <= w_input_last_valid and to_stdlogic((r_write_page_index + 1) = r_read_page_index);
      Error_underflow <= (not(r_read_active) and not(IMMEDIATE_READ) and Output_read) and not(w_output_available);
    end if;
  end process;

end architecture rtl;
