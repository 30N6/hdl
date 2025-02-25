library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity udp_tx is
port (
  Clk               : in  std_logic;
  Rst               : in  std_logic;

  Header_wr_en      : in  std_logic;
  Header_wr_addr    : in  unsigned(ETH_TX_HEADER_ADDR_WIDTH - 1 downto 0);
  Header_wr_data    : in  std_logic_vector(31 downto 0);

  Udp_length        : in  unsigned(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  Udp_data          : in  std_logic_vector(7 downto 0);
  Udp_valid         : in  std_logic;
  Udp_last          : in  std_logic;
  Udp_ready         : out std_logic;

  Mac_payload_data  : out std_logic_vector(7 downto 0);
  Mac_payload_valid : out std_logic;
  Mac_payload_last  : out std_logic;
  Mac_payload_ready : in  std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity udp_tx;

architecture rtl of udp_tx is

  type state_t is (S_IDLE, S_HEADER, S_PAYLOAD, S_DROP, S_DONE);

  constant INPUT_FIFO_WIDTH               : natural := 8 + ETH_UDP_LENGTH_WIDTH;

  constant OUTPUT_FIFO_WIDTH              : natural := 8 + 1;
  constant OUTPUT_FIFO_DEPTH              : natural := 32;
  constant OUTPUT_FIFO_ALMOST_FULL_LEVEL  : natural := OUTPUT_FIFO_DEPTH - 8;

  signal r_rst                            : std_logic;
  signal r_header_wr_en                   : std_logic;
  signal r_header_wr_addr                 : unsigned(ETH_TX_HEADER_ADDR_WIDTH - 1 downto 0);
  signal r_header_wr_data                 : std_logic_vector(31 downto 0);
  signal r_header_valid                   : std_logic;

  signal w_input_wr_data                  : std_logic_vector(INPUT_FIFO_WIDTH - 1 downto 0);
  signal w_input_rd_data                  : std_logic_vector(INPUT_FIFO_WIDTH - 1 downto 0);
  signal w_input_data                     : std_logic_vector(7 downto 0);
  signal w_input_length                   : unsigned(ETH_UDP_LENGTH_WIDTH - 1 downto 0);
  signal w_input_valid                    : std_logic;
  signal w_input_last                     : std_logic;
  signal w_input_ready                    : std_logic;

  signal r_header                         : std_logic_vector(ETH_TX_HEADER_WORD_LENGTH * 32 - 1 downto 0);
  signal w_header                         : std_logic_vector(ETH_IP_UDP_HEADER_BYTE_LENGTH * 8 - 1 downto 0);

  signal r_udp_length                     : unsigned(15 downto 0);
  signal r_ip_total_length                : unsigned(15 downto 0);
  signal w_ip_header_partial_checksum     : unsigned(15 downto 0);
  signal w_ip_header_partial_checksum_s   : unsigned(15 downto 0);
  signal r_ip_header_checksum_unfolded    : unsigned(16 downto 0);  --two terms = one extra bit
  signal r_ip_header_checksum             : unsigned(15 downto 0);

  signal s_state                          : state_t;
  signal r_state_sub_count                : unsigned(4 downto 0);

  signal w_output_fifo_wr_en              : std_logic;
  signal w_output_fifo_wr_last            : std_logic;
  signal w_output_fifo_wr_data            : std_logic_vector(7 downto 0);

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
      r_header_wr_en    <= Header_wr_en;
      r_header_wr_addr  <= Header_wr_addr;
      r_header_wr_data  <= Header_wr_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      for i in 0 to (ETH_TX_HEADER_WORD_LENGTH - 1) loop
        if ((r_header_wr_en = '1') and (r_header_wr_addr = i)) then
          r_header(32*i + 31 downto 32*i) <= r_header_wr_data;
        end if;
      end loop;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_header_valid <= '0';
      else
        if ((r_header_wr_en = '1') and (r_header_wr_addr = (ETH_TX_HEADER_WORD_LENGTH - 1))) then
          r_header_valid <= '1';
        end if;
      end if;
    end if;
  end process;

  w_input_wr_data <= std_logic_vector(Udp_length) & Udp_data;
  w_input_ready   <= not(w_output_fifo_almost_full) and to_stdlogic((s_state = S_PAYLOAD) or (s_state = S_DROP));

  i_input_fifo : entity axi_lib.axis_minififo
  generic map (
    AXI_DATA_WIDTH => INPUT_FIFO_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    S_axis_ready  => Udp_ready,
    S_axis_valid  => Udp_valid,
    S_axis_data   => w_input_wr_data,
    S_axis_last   => Udp_last,

    M_axis_ready  => w_input_ready,
    M_axis_valid  => w_input_valid,
    M_axis_data   => w_input_rd_data,
    M_axis_last   => w_input_last
  );

  w_input_data    <= w_input_rd_data(7 downto 0);
  w_input_length  <= unsigned(w_input_rd_data(ETH_UDP_LENGTH_WIDTH + 8 - 1 downto 8));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        if (w_output_fifo_almost_full = '0') then
          case s_state is
          when S_IDLE =>
            if (w_input_valid = '1') then
              if (r_header_valid = '1') then
                s_state <= S_HEADER;
              else
                s_state <= S_DROP;
              end if;
            else
              s_state <= S_IDLE;
            end if;

          when S_HEADER =>
            if (r_state_sub_count = (ETH_IP_UDP_HEADER_BYTE_LENGTH - 1)) then
              s_state <= S_PAYLOAD;
            else
              s_state <= S_HEADER;
            end if;

          when S_PAYLOAD =>
            if ((w_input_valid = '1') and (w_input_last = '1')) then
              s_state <= S_DONE;
            else
              s_state <= S_PAYLOAD;
            end if;

          when S_DROP =>
            if ((w_input_valid = '1') and (w_input_last = '1')) then
              s_state <= S_DONE;
            else
              s_state <= S_DROP;
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
      if (w_output_fifo_almost_full = '0') then
        if (s_state = S_HEADER) then
          r_state_sub_count <= r_state_sub_count + 1;
        else
          r_state_sub_count <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  w_ip_header_partial_checksum    <= unsigned(r_header(207 downto 192));
  w_ip_header_partial_checksum_s  <= byteswap(w_ip_header_partial_checksum, 8);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_udp_length <= resize_up(unsigned(w_input_length) + ETH_UDP_HEADER_LENGTH, 16);
      end if;

      r_ip_total_length             <= r_udp_length + ETH_IPV4_HEADER_LENGTH;
      r_ip_header_checksum_unfolded <= ('0' & w_ip_header_partial_checksum_s) + ('0' & r_ip_total_length);
      r_ip_header_checksum          <= r_ip_header_checksum_unfolded(15 downto 0) + ('0' & r_ip_header_checksum_unfolded(16));
    end if;
  end process;

  process(all)
  begin
    w_header <= r_header(ETH_TX_HEADER_BYTE_LENGTH * 8 - 1 downto ETH_MAC_HEADER_LENGTH * 8);
    w_header(31 downto 16)    <= std_logic_vector(byteswap(r_ip_total_length, 8));
    w_header(95 downto 80)    <= std_logic_vector(byteswap(not(r_ip_header_checksum), 8));
    w_header(207 downto 192)  <= std_logic_vector(byteswap(r_udp_length, 8));
  end process;

  process(all)
  begin
    w_output_fifo_wr_en   <= '0';
    w_output_fifo_wr_last <= to_stdlogic(s_state = S_PAYLOAD) and w_input_last;
    w_output_fifo_wr_data <= (others => '-');

    if (w_output_fifo_almost_full = '0') then
      case s_state is
      when S_HEADER =>
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= shift_right(w_header, 8 * to_integer(r_state_sub_count))(7 downto 0);

      when S_PAYLOAD =>
        w_output_fifo_wr_en   <= w_input_valid;
        w_output_fifo_wr_data <= w_input_data;

      when others =>
        null;

      end case;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_fifo_wr_en   <= w_output_fifo_wr_en;
      r_output_fifo_wr_data <= w_output_fifo_wr_last & w_output_fifo_wr_data;
    end if;
  end process;

  w_output_fifo_rd_en <= Mac_payload_ready and not(w_output_fifo_empty);

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

  Mac_payload_valid  <= not(w_output_fifo_empty);
  Mac_payload_data   <= w_output_fifo_rd_data(7 downto 0);
  Mac_payload_last   <= w_output_fifo_rd_data(8);

end architecture rtl;
