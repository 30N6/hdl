library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity axi_to_udp is
generic (
  AXI_DATA_WIDTH    : natural;
  DATA_FIFO_DEPTH   : natural;
  FRAME_FIFO_DEPTH  : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  S_axis_valid  : in  std_logic;
  S_axis_data   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last   : in  std_logic;
  S_axis_ready  : out std_logic;

  Udp_length    : out unsigned(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  Udp_data      : out std_logic_vector(7 downto 0);
  Udp_valid     : out std_logic;
  Udp_last      : out std_logic;
  Udp_ready     : in  std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity axi_to_udp;

architecture rtl of axi_to_udp is

  type state_t is (S_IDLE, S_SEQ_NUM, S_ACTIVE, S_DONE);

  constant DATA_FIFO_WIDTH              : natural := 8 + 1;
  constant DATA_FIFO_ALMOST_FULL_LEVEL  : natural := DATA_FIFO_DEPTH - 8;
  constant FRAME_FIFO_ALMOST_FULL_LEVEL : natural := FRAME_FIFO_DEPTH - 8;

  signal r_rst                          : std_logic;

  signal w_input_valid                  : std_logic;
  signal w_input_data                   : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_input_last                   : std_logic;
  signal w_input_ready                  : std_logic;

  signal s_state                        : state_t;
  signal r_byte_index                   : unsigned(1 downto 0);
  signal r_data_length                  : unsigned(ETH_UDP_LENGTH_WIDTH - 1 downto 0);

  signal r_seq_num                      : unsigned(31 downto 0);

  signal w_data_fifo_wr_en              : std_logic;
  signal w_data_fifo_wr_last            : std_logic;
  signal w_data_fifo_wr_data            : std_logic_vector(7 downto 0);
  signal r_data_fifo_wr_en              : std_logic;
  signal r_data_fifo_wr_data            : std_logic_vector(DATA_FIFO_WIDTH - 1 downto 0);
  signal w_data_fifo_almost_full        : std_logic;

  signal w_data_fifo_rd_en              : std_logic;
  signal w_data_fifo_rd_data            : std_logic_vector(DATA_FIFO_WIDTH - 1 downto 0);
  signal w_data_fifo_empty              : std_logic;

  signal w_frame_fifo_wr_en             : std_logic;
  signal r_frame_fifo_wr_en             : std_logic;
  signal r_frame_fifo_wr_data           : std_logic_vector(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  signal w_frame_fifo_almost_full       : std_logic;
  signal w_frame_fifo_rd_en             : std_logic;
  signal w_frame_fifo_rd_data           : std_logic_vector(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  signal w_frame_fifo_empty             : std_logic;

  signal w_any_fifo_almost_full         : std_logic;

  attribute MARK_DEBUG                          : string;
  attribute DONT_TOUCH                          : string;
  attribute MARK_DEBUG of w_input_valid  : signal is "TRUE";
  attribute DONT_TOUCH of w_input_valid  : signal is "TRUE";
  attribute MARK_DEBUG of w_input_data : signal is "TRUE";
  attribute DONT_TOUCH of w_input_data : signal is "TRUE";
  attribute MARK_DEBUG of w_input_last  : signal is "TRUE";
  attribute DONT_TOUCH of w_input_last  : signal is "TRUE";
  attribute MARK_DEBUG of w_input_ready  : signal is "TRUE";
  attribute DONT_TOUCH of w_input_ready  : signal is "TRUE";

  attribute MARK_DEBUG of s_state  : signal is "TRUE";
  attribute DONT_TOUCH of s_state  : signal is "TRUE";
  attribute MARK_DEBUG of r_byte_index : signal is "TRUE";
  attribute DONT_TOUCH of r_byte_index : signal is "TRUE";
  attribute MARK_DEBUG of r_data_length  : signal is "TRUE";
  attribute DONT_TOUCH of r_data_length  : signal is "TRUE";
  attribute MARK_DEBUG of r_seq_num  : signal is "TRUE";
  attribute DONT_TOUCH of r_seq_num  : signal is "TRUE";

  attribute MARK_DEBUG of w_data_fifo_wr_en  : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_wr_en  : signal is "TRUE";
  attribute MARK_DEBUG of w_data_fifo_wr_last : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_wr_last : signal is "TRUE";
  attribute MARK_DEBUG of w_data_fifo_wr_data  : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_wr_data  : signal is "TRUE";
  attribute MARK_DEBUG of r_data_fifo_wr_en  : signal is "TRUE";
  attribute DONT_TOUCH of r_data_fifo_wr_en  : signal is "TRUE";
  attribute MARK_DEBUG of r_data_fifo_wr_data  : signal is "TRUE";
  attribute DONT_TOUCH of r_data_fifo_wr_data  : signal is "TRUE";
  attribute MARK_DEBUG of w_data_fifo_almost_full  : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_almost_full  : signal is "TRUE";

  attribute MARK_DEBUG of w_data_fifo_rd_en  : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_rd_en  : signal is "TRUE";
  attribute MARK_DEBUG of w_data_fifo_rd_data : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_rd_data : signal is "TRUE";
  attribute MARK_DEBUG of w_data_fifo_empty  : signal is "TRUE";
  attribute DONT_TOUCH of w_data_fifo_empty  : signal is "TRUE";

  attribute MARK_DEBUG of w_frame_fifo_wr_en  : signal is "TRUE";
  attribute DONT_TOUCH of w_frame_fifo_wr_en  : signal is "TRUE";
  attribute MARK_DEBUG of r_frame_fifo_wr_en : signal is "TRUE";
  attribute DONT_TOUCH of r_frame_fifo_wr_en : signal is "TRUE";
  attribute MARK_DEBUG of r_frame_fifo_wr_data  : signal is "TRUE";
  attribute DONT_TOUCH of r_frame_fifo_wr_data  : signal is "TRUE";
  attribute MARK_DEBUG of w_frame_fifo_almost_full  : signal is "TRUE";
  attribute DONT_TOUCH of w_frame_fifo_almost_full  : signal is "TRUE";
  attribute MARK_DEBUG of w_frame_fifo_rd_en  : signal is "TRUE";
  attribute DONT_TOUCH of w_frame_fifo_rd_en  : signal is "TRUE";
  attribute MARK_DEBUG of w_frame_fifo_rd_data  : signal is "TRUE";
  attribute DONT_TOUCH of w_frame_fifo_rd_data  : signal is "TRUE";
  attribute MARK_DEBUG of w_frame_fifo_empty  : signal is "TRUE";
  attribute DONT_TOUCH of w_frame_fifo_empty  : signal is "TRUE";

  attribute MARK_DEBUG of w_any_fifo_almost_full  : signal is "TRUE";
  attribute DONT_TOUCH of w_any_fifo_almost_full  : signal is "TRUE";

begin

  assert (AXI_DATA_WIDTH = 32)
    report "Unexpected AXI_DATA_WIDTH"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  w_any_fifo_almost_full  <= w_data_fifo_almost_full or w_frame_fifo_almost_full;
  w_input_ready           <= not(w_any_fifo_almost_full) and to_stdlogic(s_state = S_ACTIVE) and to_stdlogic(r_byte_index = 3);

  i_input_fifo : entity axi_lib.axis_minififo
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    S_axis_ready  => S_axis_ready,
    S_axis_valid  => S_axis_valid,
    S_axis_data   => S_axis_data,
    S_axis_last   => S_axis_last,

    M_axis_ready  => w_input_ready,
    M_axis_valid  => w_input_valid,
    M_axis_data   => w_input_data,
    M_axis_last   => w_input_last
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        if (w_any_fifo_almost_full = '0') then
          case s_state is
          when S_IDLE =>
            if (w_input_valid = '1') then
              s_state <= S_SEQ_NUM;
            else
              s_state <= S_IDLE;
            end if;

          when S_SEQ_NUM =>
            if (r_byte_index = 3) then
              s_state <= S_ACTIVE;
            else
              s_state <= S_SEQ_NUM;
            end if;

          when S_ACTIVE =>
            if ((w_input_valid = '1') and (w_input_last = '1') and (r_byte_index = 3)) then
              s_state <= S_DONE;
            else
              s_state <= S_ACTIVE;
            end if;

          when S_DONE =>
            s_state <= S_IDLE;

          end case;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_any_fifo_almost_full = '0') then
        if (s_state = S_IDLE) then
          r_byte_index  <= (others => '0');
          r_data_length <= to_unsigned(1, ETH_UDP_LENGTH_WIDTH);
        elsif (w_input_valid = '1') then
          r_byte_index  <= r_byte_index + 1;
          r_data_length <= r_data_length + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_seq_num <= (others => '0');
      else
        if ((w_any_fifo_almost_full = '0') and (s_state = S_DONE)) then
          r_seq_num <= r_seq_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_SEQ_NUM) then
      w_data_fifo_wr_en   <= not(w_any_fifo_almost_full);
      w_data_fifo_wr_last <= '0';
      w_data_fifo_wr_data <= shift_right(std_logic_vector(byteswap(r_seq_num, 8)), 8 * to_integer(r_byte_index))(7 downto 0);
      w_frame_fifo_wr_en  <= '0';
    elsif (s_state = S_ACTIVE) then
      w_data_fifo_wr_en   <= not(w_any_fifo_almost_full) and w_input_valid;
      w_data_fifo_wr_last <= w_input_last and to_stdlogic(r_byte_index = 3);
      w_data_fifo_wr_data <= shift_right(w_input_data, 8 * to_integer(r_byte_index))(7 downto 0);
      w_frame_fifo_wr_en  <= not(w_any_fifo_almost_full) and w_input_valid and w_input_last and to_stdlogic(r_byte_index = 3);
    else
      w_data_fifo_wr_en   <= '0';
      w_data_fifo_wr_last <= '-';
      w_data_fifo_wr_data <= (others => '-');
      w_frame_fifo_wr_en  <= '0';
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_data_fifo_wr_en     <= w_data_fifo_wr_en;
      r_data_fifo_wr_data   <= w_data_fifo_wr_last & w_data_fifo_wr_data;

      r_frame_fifo_wr_en    <= w_frame_fifo_wr_en;
      r_frame_fifo_wr_data  <= std_logic_vector(r_data_length);
    end if;
  end process;

  w_data_fifo_rd_en   <= Udp_ready and not(w_frame_fifo_empty) and not(w_data_fifo_empty);
  w_frame_fifo_rd_en  <= Udp_ready and not(w_frame_fifo_empty) and not(w_data_fifo_empty) and w_data_fifo_rd_data(8);

  i_output_data_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH        => DATA_FIFO_DEPTH,
    FIFO_WIDTH        => DATA_FIFO_WIDTH,
    ALMOST_FULL_LEVEL => DATA_FIFO_ALMOST_FULL_LEVEL
  )
  port map (
    Clk         => Clk,
    Rst         => r_rst,

    Wr_en       => r_data_fifo_wr_en,
    Wr_data     => r_data_fifo_wr_data,
    Almost_full => w_data_fifo_almost_full,
    Full        => open,

    Rd_en       => w_data_fifo_rd_en,
    Rd_data     => w_data_fifo_rd_data,
    Empty       => w_data_fifo_empty,

    Overflow    => open,
    Underflow   => open
  );

  i_output_frame_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH        => FRAME_FIFO_DEPTH,
    FIFO_WIDTH        => ETH_UDP_LENGTH_WIDTH,
    ALMOST_FULL_LEVEL => FRAME_FIFO_ALMOST_FULL_LEVEL
  )
  port map (
    Clk         => Clk,
    Rst         => r_rst,

    Wr_en       => r_frame_fifo_wr_en,
    Wr_data     => r_frame_fifo_wr_data,
    Almost_full => w_frame_fifo_almost_full,
    Full        => open,

    Rd_en       => w_frame_fifo_rd_en,
    Rd_data     => w_frame_fifo_rd_data,
    Empty       => w_frame_fifo_empty,

    Overflow    => open,
    Underflow   => open
  );

  Udp_valid   <= not(w_frame_fifo_empty) and not(w_data_fifo_empty);
  Udp_length  <= unsigned(w_frame_fifo_rd_data);
  Udp_data    <= w_data_fifo_rd_data(7 downto 0);
  Udp_last    <= w_data_fifo_rd_data(8);

end architecture rtl;
