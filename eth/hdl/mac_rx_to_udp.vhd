library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity mac_rx_to_udp is
generic (
  INPUT_BUFFER_DATA_DEPTH   : natural;
  INPUT_BUFFER_FRAME_DEPTH  : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Udp_filter_port : in  unsigned(15 downto 0);

  Mac_data        : in  std_logic_vector(7 downto 0);
  Mac_valid       : in  std_logic;
  Mac_error       : in  std_logic;
  Mac_accepted    : out std_logic;

  Udp_data        : out std_logic_vector(7 downto 0);
  Udp_valid       : out std_logic;
  Udp_last        : out std_logic;
  Udp_ready       : in  std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity mac_rx_to_udp;

architecture rtl of mac_rx_to_udp is

  type state_t is (S_IDLE, S_START, S_DST_MAC, S_SRC_MAC, S_ETH_TYPE, S_IPV4_HEADER, S_UDP_HEADER, S_UDP_PAYLOAD, S_DROP);

  constant OUTPUT_FIFO_WIDTH              : natural := 8 + 1;
  constant OUTPUT_FIFO_DEPTH              : natural := 32;
  constant OUTPUT_FIFO_ALMOST_FULL_LEVEL  : natural := OUTPUT_FIFO_DEPTH - 8;

  constant MIN_FRAME_SIZE_TO_PAD          : natural := ETH_MIN_FRAME_SIZE - ETH_FCS_LENGTH;

  signal r_rst                            : std_logic;
  signal r_udp_filter_port                : unsigned(15 downto 0);

  signal w_mac_data                       : std_logic_vector(7 downto 0);
  signal w_mac_valid                      : std_logic;
  signal w_mac_last                       : std_logic;
  signal w_mac_ready                      : std_logic;

  signal s_state                          : state_t;
  signal r_state_sub_count                : unsigned(4 downto 0);

  signal r_prev_data                      : std_logic_vector(7 downto 0);
  signal r_udp_length                     : unsigned(15 downto 0);
  signal r_udp_count                      : unsigned(15 downto 0);

  signal w_output_fifo_wr_en              : std_logic;
  signal w_output_fifo_wr_last            : std_logic;

  signal r_output_fifo_wr_en              : std_logic;
  signal r_output_fifo_wr_data            : std_logic_vector(OUTPUT_FIFO_WIDTH - 1 downto 0);
  signal w_output_fifo_almost_full        : std_logic;

  signal w_output_fifo_rd_en              : std_logic;
  signal w_output_fifo_rd_data            : std_logic_vector(OUTPUT_FIFO_WIDTH - 1 downto 0);
  signal w_output_fifo_empty              : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst             <= Rst;
      r_udp_filter_port <= Udp_filter_port;
    end if;
  end process;

  w_mac_ready <= not(w_output_fifo_almost_full) and to_stdlogic(s_state /= S_IDLE);

  i_input_buffer : entity eth_lib.gmii_buffer
  generic map (
    DATA_DEPTH    => INPUT_BUFFER_DATA_DEPTH,
    FRAME_DEPTH   => INPUT_BUFFER_FRAME_DEPTH
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_data      => Mac_data,
    Input_valid     => Mac_valid,
    Input_error     => Mac_error,
    Input_accepted  => Mac_accepted,
    Input_dropped   => open,

    Output_data     => w_mac_data,
    Output_valid    => w_mac_valid,
    Output_last     => w_mac_last,
    Output_ready    => w_mac_ready
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((w_mac_valid = '1') and (w_mac_ready = '1')) then
        r_prev_data <= w_mac_data;

        if (s_state = S_UDP_HEADER) then
          if (r_state_sub_count = 4) then
            r_udp_length(15 downto 8) <= unsigned(w_mac_data);
          elsif (r_state_sub_count = 5) then
            r_udp_length(7 downto 0) <= unsigned(w_mac_data);
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        if (w_output_fifo_almost_full = '0') then
          case s_state is
          when S_IDLE =>
            if (w_mac_valid = '1') then
              s_state <= S_START;
            else
              s_state <= S_IDLE;
            end if;

          when S_START =>
            if (w_mac_valid = '1') then
              if (w_mac_data = ETH_SFD_BYTE) then
                s_state <= S_DST_MAC;
              else
                s_state <= S_START;
              end if;
            else
              s_state <= S_START;
            end if;

          when S_DST_MAC =>
            if ((w_mac_valid = '1') and (r_state_sub_count = (ETH_MAC_LENGTH - 1))) then
              s_state <= S_SRC_MAC;
            else
              s_state <= S_DST_MAC;
            end if;

          when S_SRC_MAC =>
            if ((w_mac_valid = '1') and (r_state_sub_count = (ETH_MAC_LENGTH - 1))) then
              s_state <= S_ETH_TYPE;
            else
              s_state <= S_SRC_MAC;
            end if;

          when S_ETH_TYPE =>
            if ((w_mac_valid = '1') and (r_state_sub_count = (ETH_TYPE_LENGTH - 1))) then
              if ((w_mac_data & r_prev_data) = ETH_TYPE_IP) then
                s_state <= S_IPV4_HEADER;
              else
                s_state <= S_DROP;
              end if;
            else
              s_state <= S_ETH_TYPE;
            end if;

          when S_IPV4_HEADER =>
            if ((w_mac_valid = '1') and (r_state_sub_count = 0) and (w_mac_data /= ETH_IP_VER_IHL)) then
              s_state <= S_DROP;
            elsif ((w_mac_valid = '1') and (r_state_sub_count = 9) and (w_mac_data /= ETH_IP_PROTO_UDP)) then
              s_state <= S_DROP;
            elsif ((w_mac_valid = '1') and (r_state_sub_count = (ETH_IPV4_HEADER_LENGTH - 1))) then
              s_state <= S_UDP_HEADER;
            else
              s_state <= S_IPV4_HEADER;
            end if;

          when S_UDP_HEADER =>
            if ((w_mac_valid = '1') and (r_state_sub_count = 3) and ((r_prev_data & w_mac_data) /= std_logic_vector(r_udp_filter_port))) then
              s_state <= S_DROP;
            elsif ((w_mac_valid = '1') and (r_state_sub_count = (ETH_UDP_HEADER_LENGTH - 1))) then
              if (r_udp_length > 8) then
                s_state <= S_UDP_PAYLOAD;
              else
                s_state <= S_DROP;
              end if;
            else
              s_state <= S_UDP_HEADER;
            end if;

          when S_UDP_PAYLOAD =>
            if ((w_mac_valid = '1') and (r_udp_length = r_udp_count)) then
              s_state <= S_DROP;
            else
              s_state <= S_UDP_PAYLOAD;
            end if;

          when S_DROP =>
            s_state <= S_DROP;  --transition handled below

          end case;

          if ((w_mac_valid = '1') and (w_mac_last = '1')) then
            s_state <= S_IDLE;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_state_sub_count <= (others => '0');
      else
        if ((w_output_fifo_almost_full = '0') and (w_mac_valid = '1')) then
          case s_state is
          when S_DST_MAC | S_SRC_MAC =>
            if (r_state_sub_count = (ETH_MAC_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when S_ETH_TYPE =>
            if (r_state_sub_count = (ETH_TYPE_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when S_IPV4_HEADER =>
            if (r_state_sub_count = (ETH_IPV4_HEADER_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when S_UDP_HEADER =>
            if (r_state_sub_count = (ETH_UDP_HEADER_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when others =>
            r_state_sub_count <= (others => '0');

          end case;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((w_output_fifo_almost_full = '0') and (w_mac_valid = '1')) then
        if (s_state = S_UDP_PAYLOAD) then
          r_udp_count <= r_udp_count + 1;
        else
          r_udp_count <= to_unsigned(9, r_udp_count'length);
        end if;
      end if;
    end if;
  end process;

  w_output_fifo_wr_en   <= w_mac_valid and not(w_output_fifo_almost_full) and to_stdlogic(s_state = S_UDP_PAYLOAD);
  w_output_fifo_wr_last <= to_stdlogic(r_udp_length = r_udp_count) or w_mac_last;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_fifo_wr_en   <= w_output_fifo_wr_en;
      r_output_fifo_wr_data <= w_output_fifo_wr_last & w_mac_data;
    end if;
  end process;

  w_output_fifo_rd_en <= Udp_ready and not(w_output_fifo_empty);

  i_output_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH        => OUTPUT_FIFO_DEPTH,
    FIFO_WIDTH        => OUTPUT_FIFO_WIDTH,
    ALMOST_FULL_LEVEL => OUTPUT_FIFO_ALMOST_FULL_LEVEL
  )
  port map (
    Clk         => Clk,
    Rst         => r_rst,

    Wr_en       => r_output_fifo_wr_en,
    Wr_data     => r_output_fifo_wr_data,
    Almost_full => w_output_fifo_almost_full,
    Full        => open,

    Rd_en       => w_output_fifo_rd_en,
    Rd_data     => w_output_fifo_rd_data,
    Empty       => w_output_fifo_empty,

    Overflow    => open,
    Underflow   => open
  );

  Udp_valid  <= not(w_output_fifo_empty);
  Udp_data   <= w_output_fifo_rd_data(7 downto 0);
  Udp_last   <= w_output_fifo_rd_data(8);

end architecture rtl;
