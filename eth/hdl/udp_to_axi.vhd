library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity udp_to_axi is
generic (
  AXI_DATA_WIDTH    : natural;
  OUTPUT_FIFO_DEPTH : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Udp_data      : in  std_logic_vector(7 downto 0);
  Udp_valid     : in  std_logic;
  Udp_last      : in  std_logic;
  Udp_ready     : out std_logic;

  M_axis_valid  : out std_logic;
  M_axis_data   : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last   : out std_logic;
  M_axis_ready  : in  std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity udp_to_axi;

architecture rtl of udp_to_axi is

  type state_t is (S_IDLE, S_ACTIVE, S_DONE);

  constant OUTPUT_FIFO_WIDTH              : natural := AXI_DATA_WIDTH + 1;
  constant OUTPUT_FIFO_ALMOST_FULL_LEVEL  : natural := OUTPUT_FIFO_DEPTH - 8;

  signal r_rst                            : std_logic;

  signal w_input_valid                    : std_logic;
  signal w_input_data                     : std_logic_vector(7 downto 0);
  signal w_input_last                     : std_logic;
  signal w_input_ready                    : std_logic;

  signal s_state                          : state_t;
  signal r_byte_index                     : unsigned(1 downto 0);

  signal w_data_word                      : std_logic_vector(31 downto 0);
  signal r_data_word                      : std_logic_vector(31 downto 0);

  signal w_output_fifo_wr_en              : std_logic;
  signal w_output_fifo_wr_last            : std_logic;
  signal w_output_fifo_wr_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r_output_fifo_wr_en              : std_logic;
  signal r_output_fifo_wr_data            : std_logic_vector(OUTPUT_FIFO_WIDTH - 1 downto 0);
  signal w_output_fifo_almost_full        : std_logic;

  signal w_output_fifo_rd_en              : std_logic;
  signal w_output_fifo_rd_data            : std_logic_vector(OUTPUT_FIFO_WIDTH - 1 downto 0);
  signal w_output_fifo_empty              : std_logic;

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

  w_input_ready <= not(w_output_fifo_almost_full) and to_stdlogic(s_state = S_ACTIVE);

  i_input_fifo : entity axi_lib.axis_minififo
  generic map (
    AXI_DATA_WIDTH => 8
  )
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    S_axis_ready  => Udp_ready,
    S_axis_valid  => Udp_valid,
    S_axis_data   => Udp_data,
    S_axis_last   => Udp_last,

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
              s_state <= S_ACTIVE;
            else
              s_state <= S_IDLE;
            end if;

          when S_ACTIVE =>
            if ((w_input_valid = '1') and (w_input_last = '1')) then
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

  process(all)
  begin
    w_data_word <= r_data_word;

    for i in 0 to 3 loop
      if (r_byte_index = i) then
        w_data_word(8 * i + 7 downto 8 * i) <= w_input_data;
      end if;
    end loop;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((w_output_fifo_almost_full = '0') and (w_input_valid = '1')) then
        if (s_state = S_IDLE) then
          r_byte_index <= (others => '0');
        else
          r_byte_index <= r_byte_index + 1;
        end if;

        r_data_word <= w_data_word;
      end if;
    end if;
  end process;

  w_output_fifo_wr_en   <= to_stdlogic(s_state = S_ACTIVE) and not(w_output_fifo_almost_full) and w_input_valid and (to_stdlogic(r_byte_index = 3) or w_input_last);
  w_output_fifo_wr_last <= w_input_last;
  w_output_fifo_wr_data <= w_data_word;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_fifo_wr_en   <= w_output_fifo_wr_en;
      r_output_fifo_wr_data <= w_output_fifo_wr_last & w_output_fifo_wr_data;
    end if;
  end process;

  w_output_fifo_rd_en <= M_axis_ready and not(w_output_fifo_empty);

  i_output_data_fifo : entity mem_lib.xpm_fallthrough_fifo
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

  M_axis_valid  <= not(w_output_fifo_empty);
  M_axis_data   <= w_output_fifo_rd_data(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last   <= w_output_fifo_rd_data(AXI_DATA_WIDTH);


end architecture rtl;
