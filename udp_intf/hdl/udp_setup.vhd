library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

library udp_intf_lib;
  use udp_intf_lib.udp_intf_pkg.all;

entity udp_setup is
generic (
  AXI_DATA_WIDTH  : natural
);
port (
  Clk             : in  std_logic;
  Clk_axi         : in  std_logic;
  Rst             : in  std_logic;
  Rst_axi         : in  std_logic;

  Udp_axis_valid  : in  std_logic;
  Udp_axis_data   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Udp_axis_last   : in  std_logic;
  Udp_axis_ready  : out std_logic;

  Header_wr_en    : out std_logic;
  Header_wr_addr  : out unsigned(ETH_TX_HEADER_ADDR_WIDTH - 1 downto 0);
  Header_wr_data  : out std_logic_vector(31 downto 0)
);
end entity udp_setup;

architecture rtl of udp_setup is

  type state_t is (S_IDLE, S_MAGIC_1, S_PAYLOAD, S_DROP);

  signal r_rst            : std_logic;
  signal w_udp_axis_valid : std_logic;
  signal w_udp_axis_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_udp_axis_last  : std_logic;

  signal s_state          : state_t;
  signal r_payload_len    : unsigned(ETH_TX_HEADER_ADDR_WIDTH - 1 downto 0);

begin

  assert (AXI_DATA_WIDTH = 32)
    report "Unexpected AXI_DATA_WIDTH"
    severity failure;

  i_input_cdc : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH        => 512,
    ALMOST_FULL_LEVEL => 512 - 5,
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk          => Clk_axi,
    S_axis_resetn       => not(Rst_axi),
    S_axis_ready        => Udp_axis_ready,
    S_axis_valid        => Udp_axis_valid,
    S_axis_data         => Udp_axis_data,
    S_axis_last         => Udp_axis_last,
    S_axis_almost_full  => open,

    M_axis_clk          => Clk,
    M_axis_ready        => '1',
    M_axis_valid        => w_udp_axis_valid,
    M_axis_data         => w_udp_axis_data,
    M_axis_last         => w_udp_axis_last
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        if (w_udp_axis_valid = '1') then
          case s_state is
          when S_IDLE =>
            if (w_udp_axis_data = UDP_SETUP_MAGIC_NUM_0) then
              s_state <= S_MAGIC_1;
            else
              s_state <= S_DROP;
            end if;

          when S_MAGIC_1 =>
            if (w_udp_axis_data = UDP_SETUP_MAGIC_NUM_1) then
              s_state <= S_PAYLOAD;
            else
              s_state <= S_DROP;
            end if;

          when S_PAYLOAD =>
            if (r_payload_len = (ETH_TX_HEADER_WORD_LENGTH - 1)) then
              s_state <= S_DROP;
            else
              s_state <= S_PAYLOAD;
            end if;

          when S_DROP =>
            null; --transition handled below

          end case;

          if (w_udp_axis_last = '1') then
            s_state <= S_IDLE;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_udp_axis_valid = '1') then
        if (s_state = S_PAYLOAD) then
          r_payload_len <= r_payload_len + 1;
        else
          r_payload_len <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Header_wr_en    <= w_udp_axis_valid and to_stdlogic(s_state = S_PAYLOAD);
      Header_wr_addr  <= r_payload_len;
      Header_wr_data  <= w_udp_axis_data;
    end if;
  end process;

end architecture rtl;
