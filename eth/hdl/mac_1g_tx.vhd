library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity mac_1g_tx is
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Source_mac    : in  std_logic_vector(47 downto 0);
  Dest_mac      : in  std_logic_vector(47 downto 0);

  Payload_data  : in  std_logic_vector(7 downto 0);
  Payload_valid : in  std_logic;
  Payload_last  : in  std_logic;
  Payload_ready : out std_logic;

  Mac_data      : out std_logic_vector(7 downto 0);
  Mac_valid     : out std_logic;
  Mac_last      : out std_logic;
  Mac_ready     : in  std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity mac_1g_tx;

architecture rtl of mac_1g_tx is

  type state_t is (S_IDLE, S_PREAMBLE, S_SFD, S_SRC_MAC, S_DST_MAC, S_ETH_TYPE, S_PAYLOAD, S_PAD, S_FCS, S_IFG);

  constant OUTPUT_FIFO_WIDTH              : natural := 8 + 1;
  constant OUTPUT_FIFO_DEPTH              : natural := 32;
  constant OUTPUT_FIFO_ALMOST_FULL_LEVEL  : natural := OUTPUT_FIFO_DEPTH - 8;

  constant MIN_FRAME_SIZE_TO_PAD          : natural := ETH_MIN_FRAME_SIZE - ETH_FCS_LENGTH;

  signal r_rst                            : std_logic;
  signal r_src_mac                        : std_logic_vector(47 downto 0);
  signal r_dst_mac                        : std_logic_vector(47 downto 0);

  signal s_state                          : state_t;
  signal r_state_sub_count                : unsigned(3 downto 0);

  signal w_frame_size_inc                 : std_logic;
  signal r_frame_size                     : unsigned(clog2(ETH_MAX_FRAME_SIZE) - 1 downto 0);

  signal w_fcs_valid                      : std_logic;
  signal w_fcs_reset                      : std_logic;
  signal w_fcs                            : std_logic_vector(31 downto 0);

  signal w_input_data                     : std_logic_vector(7 downto 0);
  signal w_input_valid                    : std_logic;
  signal w_input_last                     : std_logic;
  signal w_input_ready                    : std_logic;

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
      r_rst     <= Rst;
      r_src_mac <= Source_mac;
      r_dst_mac <= Dest_mac;
    end if;
  end process;

  w_input_ready <= not(w_output_fifo_almost_full) and to_stdlogic(s_state = S_PAYLOAD);

  i_input_fifo : entity axi_lib.axis_minififo
  generic map (
    AXI_DATA_WIDTH => 8
  )
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    S_axis_ready  => Payload_ready,
    S_axis_valid  => Payload_valid,
    S_axis_data   => Payload_data,
    S_axis_last   => Payload_last,

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
        if (w_output_fifo_almost_full = '0') then
          case s_state is
          when S_IDLE =>
            if (w_input_valid = '1') then
              s_state <= S_PREAMBLE;
            else
              s_state <= S_IDLE;
            end if;

          when S_PREAMBLE =>
            if (r_state_sub_count = (ETH_PREAMBLE_LENGTH - 1)) then
              s_state <= S_SFD;
            else
              s_state <= S_PREAMBLE;
            end if;

          when S_SFD =>
            s_state <= S_DST_MAC;

          when S_DST_MAC =>
            if (r_state_sub_count = (ETH_MAC_LENGTH - 1)) then
              s_state <= S_SRC_MAC;
            else
              s_state <= S_DST_MAC;
            end if;

          when S_SRC_MAC =>
            if (r_state_sub_count = (ETH_MAC_LENGTH - 1)) then
              s_state <= S_ETH_TYPE;
            else
              s_state <= S_SRC_MAC;
            end if;

          when S_ETH_TYPE =>
            if (r_state_sub_count = (ETH_TYPE_LENGTH - 1)) then
              s_state <= S_PAYLOAD;
            else
              s_state <= S_ETH_TYPE;
            end if;

          when S_PAYLOAD =>
            if ((w_input_valid = '1') and (w_input_last = '1')) then
              if (r_frame_size < (MIN_FRAME_SIZE_TO_PAD - 1)) then
                s_state <= S_PAD;
              else
                s_state <= S_FCS;
              end if;
            else
              s_state <= S_PAYLOAD;
            end if;

          when S_PAD =>
            if (r_frame_size < (MIN_FRAME_SIZE_TO_PAD - 1)) then
              s_state <= S_PAD;
            else
              s_state <= S_FCS;
            end if;

          when S_FCS =>
            if (r_state_sub_count = (ETH_FCS_LENGTH - 1)) then
              s_state <= S_IFG;
            else
              s_state <= S_FCS;
            end if;

          when S_IFG =>
            if (r_state_sub_count = (ETH_IFG_LENGTH - 1)) then
              s_state <= S_IDLE;
            else
              s_state <= S_IFG;
            end if;

          end case;
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
        if (w_output_fifo_almost_full = '0') then
          case s_state is
          when S_PREAMBLE =>
            r_state_sub_count <= r_state_sub_count + 1;

          when S_DST_MAC | S_SRC_MAC =>
            if (r_state_sub_count = (ETH_MAC_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when S_ETH_TYPE =>
            r_state_sub_count <= r_state_sub_count + 1;

          when S_FCS =>
            if (r_state_sub_count = (ETH_FCS_LENGTH - 1)) then
              r_state_sub_count <= (others => '0');
            else
              r_state_sub_count <= r_state_sub_count + 1;
            end if;

          when S_IFG =>
            r_state_sub_count <= r_state_sub_count + 1;

          when others =>
            r_state_sub_count <= (others => '0');

          end case;
        end if;
      end if;
    end if;
  end process;

  process(all)
  begin
    w_frame_size_inc      <= '0';
    w_fcs_valid           <= '0';
    w_output_fifo_wr_en   <= '0';
    w_output_fifo_wr_last <= to_stdlogic((s_state = S_FCS) and (r_state_sub_count = (ETH_FCS_LENGTH - 1)));
    w_output_fifo_wr_data <= (others => '-');

    if (w_output_fifo_almost_full = '0') then
      case s_state is
      when S_PREAMBLE =>
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= ETH_PREAMBLE_BYTE;

      when S_SFD =>
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= ETH_SFD_BYTE;

      when S_DST_MAC =>
        w_frame_size_inc      <= '1';
        w_fcs_valid           <= '1';
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= shift_right(r_dst_mac, 8 * to_integer(r_state_sub_count))(7 downto 0);

      when S_SRC_MAC =>
        w_frame_size_inc      <= '1';
        w_fcs_valid           <= '1';
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= shift_right(r_src_mac, 8 * to_integer(r_state_sub_count))(7 downto 0);

      when S_ETH_TYPE =>
        w_frame_size_inc      <= '1';
        w_fcs_valid           <= '1';
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= shift_right(ETH_TYPE_IP, 8 * to_integer(r_state_sub_count))(7 downto 0);

      when S_PAYLOAD =>
        w_frame_size_inc      <= w_input_valid;
        w_fcs_valid           <= w_input_valid;
        w_output_fifo_wr_en   <= w_input_valid;
        w_output_fifo_wr_data <= w_input_data;

      when S_PAD =>
        w_frame_size_inc      <= '1';
        w_fcs_valid           <= '1';
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= (others => '0');

      when S_FCS =>
        w_frame_size_inc      <= '1';
        w_output_fifo_wr_en   <= '1';
        w_output_fifo_wr_data <= shift_right(w_fcs, 8 * to_integer(r_state_sub_count))(7 downto 0);

      when others =>
        null;

      end case;
    end if;
  end process;

  w_fcs_reset <= to_stdlogic(s_state = S_IDLE);

  i_fcs : entity eth_lib.ethernet_fcs
  port map (
    Clk       => Clk,
    Rst       => w_fcs_reset,

    In_valid  => w_fcs_valid,
    In_data   => w_output_fifo_wr_data,

    Out_fcs   => w_fcs
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_frame_size <= (others => '0');
      elsif (w_frame_size_inc = '1') then
        r_frame_size <= r_frame_size + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_fifo_wr_en   <= w_output_fifo_wr_en;
      r_output_fifo_wr_data <= w_output_fifo_wr_last & w_output_fifo_wr_data;
    end if;
  end process;

  w_output_fifo_rd_en <= Mac_ready and not(w_output_fifo_empty);

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

  Mac_valid  <= not(w_output_fifo_empty);
  Mac_data   <= w_output_fifo_rd_data(7 downto 0);
  Mac_last   <= w_output_fifo_rd_data(8);

end architecture rtl;
