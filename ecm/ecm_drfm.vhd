library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library mem_lib;

entity ecm_drfm is
generic (
  OUTPUT_DATA_WIDTH   : natural;
  LATENCY             : natural
);
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Dwell_active            : in  std_logic;
  Dwell_done              : in  std_logic;
  Dwell_tx_enabled        : in  std_logic;
  Dwell_sequence_num      : in  unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_reports_done      : out std_logic;

  Write_req               : in  ecm_drfm_write_req_t;
  Read_req                : in  ecm_drfm_read_req_t;

  Output_ctrl             : out channelizer_control_t;
  Output_data             : out signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  Axis_ready              : in  std_logic;
  Axis_valid              : out std_logic;
  Axis_data               : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last               : out std_logic;

  Error_ext_read_overflow : out std_logic;
  Error_int_read_overflow : out std_logic;
  Error_reporter_timeout  : out std_logic;
  Error_reporter_overflow : out std_logic
);
end entity ecm_drfm;

architecture rtl of ecm_drfm is

  constant MEM_WIDTH                    : natural := ECM_DRFM_DATA_WIDTH * 2;
  constant MEM_LATENCY                  : natural := 2;

  signal r_rst                          : std_logic;
  signal r_dwell_active                 : std_logic;
  signal r_dwell_done                   : std_logic;
  signal r_dwell_tx_enabled             : std_logic;
  signal r_dwell_sequence_num           : std_logic;

  signal r_timestamp                    : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);

  signal r0_write_req                   : ecm_drfm_write_req_t;
  signal r0_read_req                    : ecm_drfm_read_req_t;
  signal w0_mem_wr_data                 : std_logic_vector(MEM_WIDTH - 1 downto 0);
  signal w0_mem_rd_addr                 : std_logic_vector(ECM_DRFM_ADDR_WIDTH - 1 downto 0);

  signal r1_write_req                   : ecm_drfm_write_req_t;
  signal r1_read_req                    : ecm_drfm_read_req_t;
  signal r1_read_valid                  : std_logic;
  signal r1_write_abs_data              : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);
  signal r1_prev_max_iq                 : signed(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal w2_mem_rd_data                 : std_logic_vector(MEM_WIDTH - 1 downto 0);
  signal r2_write_req                   : ecm_drfm_write_req_t;
  signal r2_read_req                    : ecm_drfm_read_req_t;
  signal r2_read_valid                  : std_logic;
  signal r2_max_iq_wr_valid             : std_logic;
  signal r2_max_iq_wr_data              : signed_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal r_channel_written              : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  signal r_channel_read                 : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  signal r_channel_report_pending       : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);

  signal m_timestamp                    : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  signal m_address_first                : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal m_address_last                 : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal m_max_iq                       : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal w_reporter_channel_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_reporter_channel_timestamp   : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_reporter_channel_addr_first  : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_reporter_channel_addr_last   : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);

  signal w_reporter_mem_read_valid      : std_logic;
  signal w_reporter_mem_read_addr       : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_reporter_mem_read_valid      : std_logic;
  signal r_reporter_mem_read_addr       : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_reporter_mem_result_valid    : std_logic;
  signal r_reporter_mem_result_data     : std_logic_vector(MEM_WIDTH - 1 downto 0);


  signal r6_sync_data                 : channelizer_control_t;
  signal r6_output_data               : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

begin

  assert (LATENCY = 8)
    report "Unexpected LATENCY value."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst                 <= Rst;
      r_dwell_active        <= Dwell_active;
      r_dwell_done          <= Dwell_done;
      r_dwell_tx_enabled    <= Dwell_tx_enabled;
      r_dwell_sequence_num  <= Dwell_sequence_num;
      r0_write_req          <= Write_req;
      r0_read_req           <= Read_req;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_timestamp <= (others => '0');
      else
        r_timestamp <= r_timestamp + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_reporter_mem_read_valid = '1') then
        r_reporter_mem_read_valid <= '1';
      elsif (r0_read_req.valid = '0') then
        r_reporter_mem_read_valid <= '0';
      end if;

      if (w_reporter_mem_read_valid = '1') then
        r_reporter_mem_read_addr <= w_reporter_mem_read_addr;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (r0_read_req.valid = '1') then
      w0_mem_rd_addr  <= r0_read_req.address; --TODO: mux for reporting
      w0_read_valid   <= '1';
    else
      w0_mem_rd_addr  <= r_reporter_mem_read_addr;
      w0_read_valid   <= r_reporter_mem_read_valid;
    end if;
  end process;

  w0_mem_wr_data <= std_logic_vector(r0_write_req.data(1) & r0_write_req.data(0));

  i_mem : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH    => ECM_DRFM_ADDR_WIDTH,
    DATA_WIDTH    => MEM_WIDTH,
    LATENCY       => MEM_LATENCY
  )
  port map (
    Clk       => Clk,

    Wr_en     => r0_write_req.valid,
    Wr_addr   => r0_write_req.address,
    Wr_data   => w0_mem_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w0_mem_rd_addr,
    Rd_data   => w2_mem_rd_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_write_req      <= r0_write_req;
      r1_read_req       <= r0_read_req;
      r1_read_valid     <= w0_read_valid;
      r1_write_abs_data <= (abs(r1_write_req.data(1)), abs(r1_write_req.data(0)));
      r1_prev_max_iq    <= m_max_iq(to_integer(r0_write_req.channel_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_write_req        <= r1_write_req;
      r2_read_req         <= r1_read_req;
      r2_read_valid       <= r1_read_valid;

      if ((r1_write_req.valid = '1') and (r1_write_req.first = '1')) then
        r2_max_iq_wr_valid  <= '1';
        if (r1_write_abs_data(0) > r1_write_abs_data(1)) then
          r2_max_iq_wr_data <= r1_write_abs_data(0);
        else
          r2_max_iq_wr_data <= r1_write_abs_data(1);
        end if;
      elsif ((r1_write_req.valid = '1') and (r1_write_abs_data(0) > r1_prev_max_iq))
        r2_max_iq_wr_valid  <= '1';
        r2_max_iq_wr_data   <= r1_write_abs_data(0);
      elsif ((r1_write_req.valid = '1') and (r1_write_abs_data(1) > r1_prev_max_iq))
        r2_max_iq_wr_valid  <= '1';
        r2_max_iq_wr_data   <= r1_write_abs_data(1);
      else
        r2_max_iq_wr_valid  <= '0';
        r2_max_iq_wr_data   <= (others => '-');
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r2_max_iq_wr_valid = '1') then
        m_max_iq(to_integer(r2_write_req.channel_index)) <= r2_max_iq_wr_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_dwell_active = '0') then
        r_channel_written         <= (others => '0');
        r_channel_read            <= (others => '0');
        r_channel_report_pending  <= (others => '0');
      else
        if (r_write_req.valid = '1') then
          r_channel_written(to_integer(r_write_req.channel_index)) <= '1';
        end if;

        if (r0_read_req.valid = '1') then
          r_channel_read(to_integer(r0_read_req.channel_index)) <= '1';
        end if;

        --TODO: clear when reported
        if ((r_write_req.valid = '1') and (r_write_req.last = '1')) then
          r_channel_report_pending(to_integer(r_write_req.channel_index)) <= '1';
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((r_write_req.valid = '1') and (r_write_req.first = '1')) then
        m_timestamp(to_integer(r_write_req.channel_index))      <= r_timestamp;
        m_address_first(to_integer(r_write_req.channel_index))  <= r_write_req.address;
      end if;
      if ((r_write_req.valid = '1') and (r_write_req.last = '1')) then
        m_address_last(to_integer(r_write_req.channel_index))  <= r_write_req.address;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_reporter_channel_timestamp  <= m_timestamp(to_integer(w_reporter_channel_index));
      r_reporter_channel_addr_first <= m_address_first(to_integer(w_reporter_channel_index));
      r_reporter_channel_addr_last  <= m_address_last(to_integer(w_reporter_channel_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_reporter_mem_result_valid <= r2_read_valid and not(r2_read_req.valid);
      r_reporter_mem_result_data  <= w2_mem_rd_data;
    end if;
  end process;

  i_reporter : entity ecm_lib.ecm_drfm_reporter
  generic map (
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH,
    MEM_WIDTH       => MEM_WIDTH
  )
  port map (
    Clk_axi             => Clk_axi,
    Clk                 => Clk,
    Rst                 => r_rst,

    Dwell_active        => r_dwell_active,
    Dwell_done          => r_dwell_done,
    Dwell_tx_enabled    => r_dwell_tx_enabled,
    Dwell_sequence_num  => r_dwell_sequence_num,
    Dwell_reports_done  => Dwell_reports_done,

    Channel_read_index  => w_reporter_channel_index,
    Channel_timestamp   => r_reporter_channel_timestamp,
    Channel_addr_first  => r_reporter_channel_addr_first,
    Channel addr_last   => r_reporter_channel_addr_last,

    Read_valid          => w_reporter_mem_read_valid,
    Read_addr           => w_reporter_mem_read_addr,
    Read_result_valid   => r_reporter_mem_result_valid,
    Read_result_data    => r_reporter_mem_result_data,

    Axis_ready          => Axis_ready,
    Axis_valid          => Axis_valid,
    Axis_data           => Axis_data,
    Axis_last           => Axis_last,

    Error_timeout       => Error_reporter_timeout,
    Error_overflow      => Error_reporter_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_ext_read_overflow <= r_read_req.valid and Read_req.valid;
      Error_int_read_overflow <= w_reporter_mem_read_valid and r_reporter_mem_read_valid and r0_read_req.valid;
    end if;
  end process;

end architecture rtl;
