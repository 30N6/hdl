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

entity udp_intf is
generic (
  AXI_DATA_WIDTH      : natural;
  OUTPUT_FIFO_DEPTH   : natural;
  TX_THROTTLE_CYCLES  : natural
);
port (
  Sys_clk         : in  std_logic;
  Sys_rst         : in  std_logic;

  Ps_gmii_rx_clk  : out std_logic;
  Ps_gmii_tx_clk  : out std_logic;
  Ps_gmii_col     : out std_logic;
  Ps_gmii_crs     : out std_logic;
  Ps_gmii_rx_dv   : out std_logic;
  Ps_gmii_rx_er   : out std_logic;
  Ps_gmii_rxd     : out std_logic_vector(7 downto 0);
  Ps_gmii_tx_en   : in  std_logic;
  Ps_gmii_tx_er   : in  std_logic;
  Ps_gmii_txd     : in  std_logic_vector(7 downto 0);

  Hw_gmii_rx_clk  : in  std_logic;
  Hw_gmii_tx_clk  : in  std_logic;
  Hw_gmii_col     : in  std_logic;
  Hw_gmii_crs     : in  std_logic;
  Hw_gmii_rx_dv   : in  std_logic;
  Hw_gmii_rx_er   : in  std_logic;
  Hw_gmii_rxd     : in  std_logic_vector(7 downto 0);
  Hw_gmii_tx_en   : out std_logic;
  Hw_gmii_tx_er   : out std_logic;
  Hw_gmii_txd     : out std_logic_vector(7 downto 0);

  S_axis_clk      : in  std_logic;
  S_axis_resetn   : in  std_logic;
  S_axis_valid    : in  std_logic;
  S_axis_data     : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last     : in  std_logic;
  S_axis_ready    : out std_logic;

  M_axis_clk      : in  std_logic;
  M_axis_valid    : out std_logic;
  M_axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last     : out std_logic;
  M_axis_ready    : in  std_logic
);
end entity udp_intf;

architecture rtl of udp_intf is

  constant SLAVE_FIFO_DEPTH           : natural := 1024;
  constant MASTER_FIFO_DEPTH          : natural := 1024;
  constant TX_AXI_TO_UDP_DATA_DEPTH   : natural := 4096;
  constant TX_AXI_TO_UDP_FRAME_DEPTH  : natural := 64;
  constant TX_BUFFER_DATA_DEPTH       : natural := 131072;
  constant TX_BUFFER_FRAME_DEPTH      : natural := 1024;
  constant RX_TO_UDP_DATA_DEPTH       : natural := 2048;
  constant RX_TO_UDP_FRAME_DEPTH      : natural := 32;
  constant RX_UDP_TO_AXI_FIFO_DEPTH   : natural := 32;

  constant CDC_PIPE_STAGES            : natural := 3;

  signal r_sys_rst                    : std_logic;
  signal r_rst_gmii_rx                : std_logic_vector(CDC_PIPE_STAGES - 1 downto 0);
  signal r_rst_gmii_tx                : std_logic_vector(CDC_PIPE_STAGES - 1 downto 0);

  signal w_tx_header_wr_en            : std_logic;
  signal w_tx_header_wr_addr          : unsigned(ETH_TX_HEADER_ADDR_WIDTH - 1 downto 0);
  signal w_tx_header_wr_data          : std_logic_vector(31 downto 0);

  signal w_s_axis_ready               : std_logic;
  signal w_s_axis_valid               : std_logic;
  signal w_s_axis_data                : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_s_axis_last                : std_logic;

  signal w_from_axi_to_udp_length     : unsigned(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  signal w_from_axi_to_udp_data       : std_logic_vector(7 downto 0);
  signal w_from_axi_to_udp_valid      : std_logic;
  signal w_from_axi_to_udp_last       : std_logic;
  signal w_from_axi_to_udp_ready      : std_logic;

  signal w_from_udp_tx_payload_data   : std_logic_vector(7 downto 0);
  signal w_from_udp_tx_payload_valid  : std_logic;
  signal w_from_udp_tx_payload_last   : std_logic;
  signal w_from_udp_tx_payload_ready  : std_logic;

  signal w_from_mac_data              : std_logic_vector(7 downto 0);
  signal w_from_mac_valid             : std_logic;
  signal w_from_mac_last              : std_logic;
  signal w_from_mac_ready             : std_logic;

  signal w_to_tx_buffer_accepted      : std_logic;
  signal w_to_tx_buffer_dropped       : std_logic;
  signal w_from_tx_buffer_data        : std_logic_vector(7 downto 0);
  signal w_from_tx_buffer_valid       : std_logic;
  signal w_from_tx_buffer_last        : std_logic;
  signal w_from_tx_buffer_ready       : std_logic;

  signal w_gmii_to_arb_data           : std_logic_vector_array_t(1 downto 0)(7 downto 0);
  signal w_gmii_to_arb_valid          : std_logic_vector(1 downto 0);
  signal w_gmii_to_arb_last           : std_logic_vector(1 downto 0);
  signal w_gmii_to_arb_ready          : std_logic_vector(1 downto 0);
  signal w_gmii_from_arb_data         : std_logic_vector(7 downto 0);
  signal w_gmii_from_arb_valid        : std_logic;
  signal w_gmii_from_arb_last         : std_logic; --unused
  signal r_gmii_from_arb_ready        : std_logic;

  signal r_gmii_throttle_counter      : unsigned(clog2(TX_THROTTLE_CYCLES) - 1 downto 0) := (others => '0');

  signal w_rx_to_udp_accepted         : std_logic;
  signal w_from_rx_to_udp_data        : std_logic_vector(7 downto 0);
  signal w_from_rx_to_udp_valid       : std_logic;
  signal w_from_rx_to_udp_last        : std_logic;
  signal w_from_rx_to_udp_ready       : std_logic;

  signal w_m_axis_valid               : std_logic;
  signal w_m_axis_data                : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_m_axis_last                : std_logic;
  signal w_m_axis_ready               : std_logic_vector(1 downto 0);

  attribute ASYNC_REG                   : string;
  attribute ASYNC_REG of r_rst_gmii_rx  : signal is "TRUE";
  attribute ASYNC_REG of r_rst_gmii_tx  : signal is "TRUE";

--  --TODO: remove
--  attribute MARK_DEBUG                          : string;
--  attribute DONT_TOUCH                          : string;
--  attribute MARK_DEBUG of w_gmii_from_arb_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_gmii_from_arb_data  : signal is "TRUE";
--  attribute MARK_DEBUG of w_gmii_from_arb_valid : signal is "TRUE";
--  attribute DONT_TOUCH of w_gmii_from_arb_valid : signal is "TRUE";
--  attribute MARK_DEBUG of w_gmii_from_arb_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_gmii_from_arb_last  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_tx_header_wr_en  : signal is "TRUE";
--  attribute DONT_TOUCH of w_tx_header_wr_en  : signal is "TRUE";
--  attribute MARK_DEBUG of w_tx_header_wr_addr : signal is "TRUE";
--  attribute DONT_TOUCH of w_tx_header_wr_addr : signal is "TRUE";
--  attribute MARK_DEBUG of w_tx_header_wr_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_tx_header_wr_data  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_s_axis_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_s_axis_ready  : signal is "TRUE";
--  attribute MARK_DEBUG of w_s_axis_valid : signal is "TRUE";
--  attribute DONT_TOUCH of w_s_axis_valid : signal is "TRUE";
--  attribute MARK_DEBUG of w_s_axis_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_s_axis_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_s_axis_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_s_axis_data  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_from_axi_to_udp_length  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_axi_to_udp_length  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_axi_to_udp_data : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_axi_to_udp_data : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_axi_to_udp_valid  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_axi_to_udp_valid  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_axi_to_udp_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_axi_to_udp_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_axi_to_udp_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_axi_to_udp_ready  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_from_udp_tx_payload_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_udp_tx_payload_data  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_udp_tx_payload_valid : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_udp_tx_payload_valid : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_udp_tx_payload_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_udp_tx_payload_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_udp_tx_payload_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_udp_tx_payload_ready  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_from_mac_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_mac_data  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_mac_valid : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_mac_valid : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_mac_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_mac_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_mac_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_mac_ready  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_to_tx_buffer_accepted  : signal is "TRUE";
--  attribute DONT_TOUCH of w_to_tx_buffer_accepted  : signal is "TRUE";
--  attribute MARK_DEBUG of w_to_tx_buffer_dropped : signal is "TRUE";
--  attribute DONT_TOUCH of w_to_tx_buffer_dropped : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_tx_buffer_data  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_tx_buffer_data  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_tx_buffer_valid  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_tx_buffer_valid  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_tx_buffer_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_tx_buffer_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_tx_buffer_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_tx_buffer_ready  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_rx_to_udp_accepted  : signal is "TRUE";
--  attribute DONT_TOUCH of w_rx_to_udp_accepted  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_rx_to_udp_data : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_rx_to_udp_data : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_rx_to_udp_valid  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_rx_to_udp_valid  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_rx_to_udp_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_rx_to_udp_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_from_rx_to_udp_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_from_rx_to_udp_ready  : signal is "TRUE";
--
--  attribute MARK_DEBUG of w_m_axis_valid  : signal is "TRUE";
--  attribute DONT_TOUCH of w_m_axis_valid  : signal is "TRUE";
--  attribute MARK_DEBUG of w_m_axis_data : signal is "TRUE";
--  attribute DONT_TOUCH of w_m_axis_data : signal is "TRUE";
--  attribute MARK_DEBUG of w_m_axis_last  : signal is "TRUE";
--  attribute DONT_TOUCH of w_m_axis_last  : signal is "TRUE";
--  attribute MARK_DEBUG of w_m_axis_ready  : signal is "TRUE";
--  attribute DONT_TOUCH of w_m_axis_ready  : signal is "TRUE";
--
--  signal w_Hw_gmii_rxd            : std_logic_vector(7 downto 0);
--  signal w_Hw_gmii_rx_dv          : std_logic;
--  signal w_Hw_gmii_rx_er          : std_logic;
--
--  attribute MARK_DEBUG of w_Hw_gmii_rxd  : signal is "TRUE";
--  attribute DONT_TOUCH of w_Hw_gmii_rxd  : signal is "TRUE";
--  attribute MARK_DEBUG of w_Hw_gmii_rx_dv : signal is "TRUE";
--  attribute DONT_TOUCH of w_Hw_gmii_rx_dv : signal is "TRUE";
--  attribute MARK_DEBUG of w_Hw_gmii_rx_er  : signal is "TRUE";
--  attribute DONT_TOUCH of w_Hw_gmii_rx_er  : signal is "TRUE";

begin

  assert (AXI_DATA_WIDTH = 32)
    report "Unexpected AXI_DATA_WIDTH"
    severity failure;

  process(Sys_clk)
  begin
    if rising_edge(Sys_clk) then
      r_sys_rst <= Sys_rst;
    end if;
  end process;

  process(Hw_gmii_rx_clk)
  begin
    if rising_edge(Hw_gmii_rx_clk) then
      r_rst_gmii_rx <= r_rst_gmii_rx(CDC_PIPE_STAGES - 2 downto 0) & r_sys_rst;
    end if;
  end process;

  process(Hw_gmii_tx_clk)
  begin
    if rising_edge(Hw_gmii_tx_clk) then
      r_rst_gmii_tx <= r_rst_gmii_tx(CDC_PIPE_STAGES - 2 downto 0) & r_sys_rst;
    end if;
  end process;

  i_udp_setup : entity udp_intf_lib.udp_setup
  generic map (
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    Clk             => Hw_gmii_tx_clk,
    Clk_axi         => Hw_gmii_rx_clk,
    Rst             => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),
    Rst_axi         => r_rst_gmii_rx(CDC_PIPE_STAGES - 1),

    Udp_axis_valid  => w_m_axis_valid and w_m_axis_ready(1),  --only transfer when both readies are high
    Udp_axis_data   => w_m_axis_data,
    Udp_axis_last   => w_m_axis_last,
    Udp_axis_ready  => w_m_axis_ready(0),

    Header_wr_en    => w_tx_header_wr_en,
    Header_wr_addr  => w_tx_header_wr_addr,
    Header_wr_data  => w_tx_header_wr_data
  );

  i_tx_axi_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH        => SLAVE_FIFO_DEPTH,
    ALMOST_FULL_LEVEL => SLAVE_FIFO_DEPTH - 5,
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk          => S_axis_clk,
    S_axis_resetn       => S_axis_resetn,
    S_axis_ready        => S_axis_ready,
    S_axis_valid        => S_axis_valid,
    S_axis_data         => S_axis_data,
    S_axis_last         => S_axis_last,
    S_axis_almost_full  => open,

    M_axis_clk          => Hw_gmii_tx_clk,
    M_axis_ready        => w_s_axis_ready,
    M_axis_valid        => w_s_axis_valid,
    M_axis_data         => w_s_axis_data,
    M_axis_last         => w_s_axis_last
  );

  i_tx_axi_to_udp : entity eth_lib.axi_to_udp
  generic map (
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH,
    DATA_FIFO_DEPTH   => TX_AXI_TO_UDP_DATA_DEPTH,
    FRAME_FIFO_DEPTH  => TX_AXI_TO_UDP_FRAME_DEPTH
  )
  port map (
    Clk           => Hw_gmii_tx_clk,
    Rst           => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),

    S_axis_valid  => w_s_axis_valid,
    S_axis_data   => w_s_axis_data,
    S_axis_last   => w_s_axis_last,
    S_axis_ready  => w_s_axis_ready,

    Udp_length    => w_from_axi_to_udp_length,
    Udp_data      => w_from_axi_to_udp_data,
    Udp_valid     => w_from_axi_to_udp_valid,
    Udp_last      => w_from_axi_to_udp_last,
    Udp_ready     => w_from_axi_to_udp_ready
  );

  i_tx_udp_tx : entity eth_lib.udp_tx
  port map (
    Clk               => Hw_gmii_tx_clk,
    Rst               => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),

    Header_wr_en      => w_tx_header_wr_en,
    Header_wr_addr    => w_tx_header_wr_addr,
    Header_wr_data    => w_tx_header_wr_data,

    Udp_length        => w_from_axi_to_udp_length,
    Udp_data          => w_from_axi_to_udp_data,
    Udp_valid         => w_from_axi_to_udp_valid,
    Udp_last          => w_from_axi_to_udp_last,
    Udp_ready         => w_from_axi_to_udp_ready,

    Mac_payload_data  => w_from_udp_tx_payload_data,
    Mac_payload_valid => w_from_udp_tx_payload_valid,
    Mac_payload_last  => w_from_udp_tx_payload_last,
    Mac_payload_ready => w_from_udp_tx_payload_ready
  );

  i_tx_mac : entity eth_lib.mac_1g_tx
  port map (
    Clk             => Hw_gmii_tx_clk,
    Rst             => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),

    Header_wr_en    => w_tx_header_wr_en,
    Header_wr_addr  => w_tx_header_wr_addr,
    Header_wr_data  => w_tx_header_wr_data,

    Payload_data    => w_from_udp_tx_payload_data,
    Payload_valid   => w_from_udp_tx_payload_valid,
    Payload_last    => w_from_udp_tx_payload_last,
    Payload_ready   => w_from_udp_tx_payload_ready,

    Mac_data        => w_from_mac_data,
    Mac_valid       => w_from_mac_valid,
    Mac_last        => w_from_mac_last,
    Mac_ready       => w_from_mac_ready
  );

  w_gmii_to_arb_data(0)   <= w_from_mac_data;
  w_gmii_to_arb_valid(0)  <= w_from_mac_valid;
  w_gmii_to_arb_last(0)   <= w_from_mac_last;
  w_from_mac_ready        <= w_gmii_to_arb_ready(0);

  i_tx_buffer : entity eth_lib.gmii_buffer
  generic map (
    DATA_DEPTH    => TX_BUFFER_DATA_DEPTH,
    FRAME_DEPTH   => TX_BUFFER_FRAME_DEPTH
  )
  port map (
    Clk             => Hw_gmii_tx_clk,
    Rst             => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),

    Input_data      => Ps_gmii_txd,
    Input_valid     => Ps_gmii_tx_en,
    Input_error     => Ps_gmii_tx_er,
    Input_accepted  => w_to_tx_buffer_accepted,
    Input_dropped   => w_to_tx_buffer_dropped,

    Output_data     => w_from_tx_buffer_data,
    Output_valid    => w_from_tx_buffer_valid,
    Output_last     => w_from_tx_buffer_last,
    Output_ready    => w_from_tx_buffer_ready
  );

  w_gmii_to_arb_data(1)   <= w_from_tx_buffer_data;
  w_gmii_to_arb_valid(1)  <= w_from_tx_buffer_valid;
  w_gmii_to_arb_last(1)   <= w_from_tx_buffer_last;
  w_from_tx_buffer_ready  <= w_gmii_to_arb_ready(1);

  process(Hw_gmii_tx_clk)
  begin
    if rising_edge(Hw_gmii_tx_clk) then
      if (r_gmii_throttle_counter = (TX_THROTTLE_CYCLES - 1)) then
        r_gmii_throttle_counter <= (others => '0');
        r_gmii_from_arb_ready   <= '1';
      else
        r_gmii_throttle_counter <= r_gmii_throttle_counter + 1;
        r_gmii_from_arb_ready   <= '0';
      end if;
    end if;
  end process;

  i_tx_arb : entity eth_lib.gmii_arb
  generic map (
    NUM_INPUTS      => 2,
    INTERFRAME_GAP  => ETH_IFG_LENGTH + 1
  )
  port map (
    Clk           => Hw_gmii_tx_clk,
    Rst           => r_rst_gmii_tx(CDC_PIPE_STAGES - 1),

    Input_data    => w_gmii_to_arb_data,
    Input_valid   => w_gmii_to_arb_valid,
    Input_last    => w_gmii_to_arb_last,
    Input_ready   => w_gmii_to_arb_ready,

    Output_data   => w_gmii_from_arb_data,
    Output_valid  => w_gmii_from_arb_valid,
    Output_last   => w_gmii_from_arb_last,
    Output_ready  => r_gmii_from_arb_ready
  );

  ------- RX -------

  --w_Hw_gmii_rxd           <= Hw_gmii_rxd;
  --w_Hw_gmii_rx_dv         <= Hw_gmii_rx_dv;
  --w_Hw_gmii_rx_er         <= Hw_gmii_rx_er;


  i_rx_to_udp : entity eth_lib.mac_rx_to_udp
  generic map (
    INPUT_BUFFER_DATA_DEPTH   => RX_TO_UDP_DATA_DEPTH,
    INPUT_BUFFER_FRAME_DEPTH  => RX_TO_UDP_FRAME_DEPTH
  )
  port map (
    Clk             => Hw_gmii_rx_clk,
    Rst             => r_rst_gmii_rx(CDC_PIPE_STAGES - 1),

    Udp_filter_port => UDP_FILTER_PORT,

    Mac_data        => Hw_gmii_rxd,
    Mac_valid       => Hw_gmii_rx_dv,
    Mac_error       => Hw_gmii_rx_er,
    Mac_accepted    => w_rx_to_udp_accepted,

    Udp_data        => w_from_rx_to_udp_data,
    Udp_valid       => w_from_rx_to_udp_valid,
    Udp_last        => w_from_rx_to_udp_last,
    Udp_ready       => w_from_rx_to_udp_ready
  );

  i_rx_udp_to_axi : entity eth_lib.udp_to_axi
  generic map (
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH,
    OUTPUT_FIFO_DEPTH => RX_UDP_TO_AXI_FIFO_DEPTH
  )
  port map (
    Clk           => Hw_gmii_rx_clk,
    Rst           => r_rst_gmii_rx(CDC_PIPE_STAGES - 1),

    Udp_data      => w_from_rx_to_udp_data,
    Udp_valid     => w_from_rx_to_udp_valid,
    Udp_last      => w_from_rx_to_udp_last,
    Udp_ready     => w_from_rx_to_udp_ready,

    M_axis_valid  => w_m_axis_valid,
    M_axis_data   => w_m_axis_data,
    M_axis_last   => w_m_axis_last,
    M_axis_ready  => and_reduce(w_m_axis_ready)
  );

  i_rx_axi_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH        => MASTER_FIFO_DEPTH,
    ALMOST_FULL_LEVEL => MASTER_FIFO_DEPTH - 5,
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk          => Hw_gmii_rx_clk,
    S_axis_resetn       => not(r_rst_gmii_rx(CDC_PIPE_STAGES - 1)),
    S_axis_ready        => w_m_axis_ready(1),
    S_axis_valid        => w_m_axis_valid and w_m_axis_ready(0), --only transfer when both readies are high
    S_axis_data         => w_m_axis_data,
    S_axis_last         => w_m_axis_last,
    S_axis_almost_full  => open,

    M_axis_clk          => M_axis_clk,
    M_axis_ready        => M_axis_ready,
    M_axis_valid        => M_axis_valid,
    M_axis_data         => M_axis_data,
    M_axis_last         => M_axis_last
  );

  Ps_gmii_rx_clk  <= Hw_gmii_rx_clk;
  Ps_gmii_tx_clk  <= Hw_gmii_tx_clk;
  Ps_gmii_col     <= Hw_gmii_col;
  Ps_gmii_crs     <= Hw_gmii_crs;
  Ps_gmii_rx_dv   <= Hw_gmii_rx_dv;
  Ps_gmii_rx_er   <= Hw_gmii_rx_er;
  Ps_gmii_rxd     <= Hw_gmii_rxd;

  Hw_gmii_tx_en   <= w_gmii_from_arb_valid;
  Hw_gmii_tx_er   <= '0';
  Hw_gmii_txd     <= w_gmii_from_arb_data;

end architecture rtl;
