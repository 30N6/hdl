library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity ecm_drfm is
generic (
  AXI_DATA_WIDTH    : natural;
  READ_LATENCY      : natural
);
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Dwell_active            : in  std_logic;
  Dwell_active_transmit   : in  std_logic;
  Dwell_done              : in  std_logic;
  Dwell_sequence_num      : in  unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_report_enable     : in  std_logic;
  Dwell_reports_done      : out std_logic;

  Write_req               : in  ecm_drfm_write_req_t;
  Read_req                : in  ecm_drfm_read_req_t;

  Output_read             : out std_logic;
  Output_ctrl             : out channelizer_control_t;
  Output_data             : out signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  Axis_ready              : in  std_logic;
  Axis_valid              : out std_logic;
  Axis_data               : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last               : out std_logic;

  Error_ext_read_overflow : out std_logic;
  Error_int_read_overflow : out std_logic;
  Error_invalid_read      : out std_logic;
  Error_reporter_timeout  : out std_logic;
  Error_reporter_overflow : out std_logic
);
end entity ecm_drfm;

architecture rtl of ecm_drfm is

  constant MEM_WIDTH                    : natural := ECM_DRFM_DATA_WIDTH * 2;
  constant MEM_LATENCY                  : natural := 3;

  function get_iq_bit_count(v : signed(ECM_DRFM_DATA_WIDTH - 1 downto 0)) return unsigned is
    variable r : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  begin
    r := to_unsigned(1, ECM_DRFM_DATA_WIDTH_WIDTH);

    for i in (ECM_DRFM_DATA_WIDTH - 2) downto 0 loop
      if (((v < 0) and (v(i) = '0')) or ((v >= 0) and (v(i) = '1'))) then
        r := to_unsigned(i + 1, ECM_DRFM_DATA_WIDTH_WIDTH);
        exit;
      end if;
    end loop;

    return r;
  end function;

  signal r_rst                            : std_logic;
  signal r_dwell_active                   : std_logic;
  signal r_dwell_active_tx                : std_logic;
  signal r_dwell_done                     : std_logic;
  signal r_dwell_report_enable            : std_logic;
  signal r_dwell_sequence_num             : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r_dwell_start                    : std_logic;

  signal r_timestamp                      : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);

  signal r0_write_req                     : ecm_drfm_write_req_t;
  signal r0_read_req                      : ecm_drfm_read_req_t;
  signal r0_write_prev_seq_num            : unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r0_mem_rd_addr                   : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r0_read_valid                    : std_logic;
  signal r0_read_reporter_last            : std_logic;
  signal w0_mem_wr_data                   : std_logic_vector(MEM_WIDTH - 1 downto 0);

  signal r1_write_req                     : ecm_drfm_write_req_t;
  signal r1_read_req                      : ecm_drfm_read_req_t;
  signal r1_read_valid                    : std_logic;
  signal r1_read_reporter_last            : std_logic;
  signal r1_read_max_iq_bits              : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal r1_write_max_iq_bits             : unsigned_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal r1_prev_max_iq_bits              : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal r1_write_next_seq_num            : unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal w1_write_max_iq_bits_sel         : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);

  signal r2_write_req                     : ecm_drfm_write_req_t;
  signal r2_read_req                      : ecm_drfm_read_req_t;
  signal r2_read_valid                    : std_logic;
  signal r2_read_reporter_last            : std_logic;
  signal r2_read_max_iq_bits              : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal r2_max_iq_wr_valid               : std_logic;
  signal r2_max_iq_wr_data                : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);

  signal r3_read_valid                    : std_logic;
  signal r3_read_reporter_last            : std_logic;
  signal r3_read_req                      : ecm_drfm_read_req_t;
  signal r3_iq_shift                      : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal w3_mem_rd_data                   : std_logic_vector(MEM_WIDTH - 1 downto 0);
  signal w3_read_data                     : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal r4_read_data_scaled              : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);
  signal r4_read_req                      : ecm_drfm_read_req_t;
  signal r4_read_valid                    : std_logic;

  signal r_channel_was_written            : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  signal r_channel_was_read               : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  signal r_channel_report_pending         : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);

  signal m_timestamp                      : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  signal m_seq_num                        : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0) := (others => (others => '1'));
  signal m_address_first                  : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal m_address_last                   : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal m_max_iq_bits                    : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal m_trigger_forced                 : std_logic_array_t(ECM_NUM_CHANNELS - 1 downto 0);

  signal w_channel_reports_done           : std_logic;
  signal w_reporter_channel_index         : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_reporter_channel_timestamp     : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_reporter_channel_seq_num       : unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r_reporter_channel_addr_first    : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_reporter_channel_addr_last     : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_reporter_channel_max_iq_bits   : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  signal r_reporter_channel_forced        : std_logic;

  signal w_reporter_mem_read_valid        : std_logic;
  signal w_reporter_mem_read_last         : std_logic;
  signal w_reporter_mem_read_addr         : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_reporter_mem_read_valid        : std_logic;
  signal r_reporter_mem_read_last         : std_logic;
  signal r_reporter_mem_read_addr         : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_reporter_mem_result_valid      : std_logic;
  signal r_reporter_mem_result_last       : std_logic;
  signal r_reporter_mem_result_data       : std_logic_vector(MEM_WIDTH - 1 downto 0);

begin

  assert (READ_LATENCY = (MEM_LATENCY + 2))
    report "Unexpected READ_LATENCY value."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst                 <= Rst;
      r_dwell_active        <= Dwell_active;
      r_dwell_start         <= Dwell_active and not(r_dwell_active);
      r_dwell_active_tx     <= Dwell_active_transmit;
      r_dwell_done          <= Dwell_done;
      r_dwell_report_enable <= Dwell_report_enable;
      r_dwell_sequence_num  <= Dwell_sequence_num;
      r0_write_req          <= Write_req;
      r0_read_req           <= Read_req;
      r0_write_prev_seq_num <= m_seq_num(to_integer(Write_req.channel_index));

      if (Read_req.read_valid = '1') then
        r0_mem_rd_addr        <= Read_req.address;
        r0_read_valid         <= '1';
        r0_read_reporter_last <= '0';
      else
        r0_mem_rd_addr        <= r_reporter_mem_read_addr;
        r0_read_valid         <= r_reporter_mem_read_valid;
        r0_read_reporter_last <= r_reporter_mem_read_last;
      end if;
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
        r_reporter_mem_read_last  <= w_reporter_mem_read_last;
      elsif (Read_req.read_valid = '0') then
        r_reporter_mem_read_valid <= '0';
        r_reporter_mem_read_last  <= '-';
      end if;

      if (w_reporter_mem_read_valid = '1') then
        r_reporter_mem_read_addr <= w_reporter_mem_read_addr;
      end if;
    end if;
  end process;

  w0_mem_wr_data <= std_logic_vector(r0_write_req.data(1)) & std_logic_vector(r0_write_req.data(0));

  i_mem : entity ecm_lib.ecm_drfm_mem
  generic map (
    DATA_WIDTH  => MEM_WIDTH,
    LATENCY     => MEM_LATENCY
  )
  port map (
    Clk       => Clk,

    Wr_en     => r0_write_req.valid,
    Wr_addr   => r0_write_req.address,
    Wr_data   => w0_mem_wr_data,

    Rd_addr   => r0_mem_rd_addr,
    Rd_data   => w3_mem_rd_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_read_req           <= r0_read_req;
      r1_read_valid         <= r0_read_valid;
      r1_read_reporter_last <= r0_read_reporter_last;
      r1_read_max_iq_bits   <= m_max_iq_bits(to_integer(r0_read_req.channel_index));

      r1_write_req          <= r0_write_req;
      r1_write_max_iq_bits  <= (get_iq_bit_count(r0_write_req.data(1)), get_iq_bit_count(r0_write_req.data(0)));
      r1_prev_max_iq_bits   <= m_max_iq_bits(to_integer(r0_write_req.channel_index));
      r1_write_next_seq_num <= r0_write_prev_seq_num + 1;
    end if;
  end process;

  process(all)
  begin
    if (r1_write_max_iq_bits(0) > r1_write_max_iq_bits(1)) then
      w1_write_max_iq_bits_sel <= r1_write_max_iq_bits(0);
    else
      w1_write_max_iq_bits_sel <= r1_write_max_iq_bits(1);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_write_req          <= r1_write_req;
      r2_read_req           <= r1_read_req;
      r2_read_valid         <= r1_read_valid;
      r2_read_reporter_last <= r1_read_reporter_last;
      r2_read_max_iq_bits   <= r1_read_max_iq_bits;

      if ((r1_write_req.valid = '1') and (r1_write_req.first = '1')) then
        r2_max_iq_wr_valid  <= '1';
        r2_max_iq_wr_data   <= w1_write_max_iq_bits_sel;
      elsif ((r1_write_req.valid = '1') and (w1_write_max_iq_bits_sel > r1_prev_max_iq_bits)) then
        r2_max_iq_wr_valid  <= '1';
        r2_max_iq_wr_data   <= w1_write_max_iq_bits_sel;
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
        m_max_iq_bits(to_integer(r2_write_req.channel_index)) <= r2_max_iq_wr_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_read_valid         <= r2_read_valid;
      r3_read_reporter_last <= r2_read_reporter_last;
      r3_read_req           <= r2_read_req;
      r3_iq_shift           <= (ECM_DRFM_DATA_WIDTH - 1) - r2_read_max_iq_bits;
    end if;
  end process;

  w3_read_data(0) <= signed(w3_mem_rd_data(ECM_DRFM_DATA_WIDTH - 1 downto 0));
  w3_read_data(1) <= signed(w3_mem_rd_data(ECM_DRFM_DATA_WIDTH * 2 - 1 downto ECM_DRFM_DATA_WIDTH));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_read_valid           <= r3_read_req.read_valid or r3_read_req.sync_valid;
      r4_read_req             <= r3_read_req;
      r4_read_data_scaled(0)  <= shift_left(w3_read_data(0), to_integer(r3_iq_shift)) when ((r_dwell_active_tx = '1') and (r3_read_req.read_valid = '1')) else (others => '0');
      r4_read_data_scaled(1)  <= shift_left(w3_read_data(1), to_integer(r3_iq_shift)) when ((r_dwell_active_tx = '1') and (r3_read_req.read_valid = '1')) else (others => '0');
    end if;
  end process;

  process(all)
  begin
    Output_read             <= r4_read_req.read_valid;
    Output_ctrl.valid       <= r4_read_valid;
    Output_ctrl.last        <= r4_read_req.channel_last;
    Output_ctrl.data_index  <= resize_up(r4_read_req.channel_index, Output_ctrl.data_index'length);
    Output_data             <= r4_read_data_scaled;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_dwell_start = '1') then
        r_channel_was_written     <= (others => '0');
        r_channel_was_read        <= (others => '0');
        r_channel_report_pending  <= (others => '0');
      else
        if (r1_write_req.valid = '1') then
          r_channel_was_written(to_integer(r1_write_req.channel_index)) <= '1';
        end if;

        if (r1_read_req.read_valid = '1') then
          r_channel_was_read(to_integer(r1_read_req.channel_index)) <= '1';
        end if;

        if ((r1_write_req.valid = '1') and (r1_write_req.last = '1')) then
          r_channel_report_pending(to_integer(r1_write_req.channel_index)) <= r1_write_req.trigger_accepted;
        end if;
        if (w_channel_reports_done = '1') then
          r_channel_report_pending(to_integer(w_reporter_channel_index)) <= '0';
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((r1_write_req.valid = '1') and (r1_write_req.first = '1')) then
        m_timestamp(to_integer(r1_write_req.channel_index))       <= r_timestamp;
        m_address_first(to_integer(r1_write_req.channel_index))   <= r1_write_req.address;
        m_seq_num(to_integer(r1_write_req.channel_index))         <= r1_write_next_seq_num;
        m_trigger_forced(to_integer(r1_write_req.channel_index))  <= r1_write_req.trigger_forced;
      end if;

      if ((r1_write_req.valid = '1') and (r1_write_req.last = '1')) then
        m_address_last(to_integer(r1_write_req.channel_index))  <= r1_write_req.address;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_reporter_channel_timestamp    <= m_timestamp(to_integer(w_reporter_channel_index));
      r_reporter_channel_seq_num      <= m_seq_num(to_integer(w_reporter_channel_index));
      r_reporter_channel_addr_first   <= m_address_first(to_integer(w_reporter_channel_index));
      r_reporter_channel_addr_last    <= m_address_last(to_integer(w_reporter_channel_index));
      r_reporter_channel_max_iq_bits  <= m_max_iq_bits(to_integer(w_reporter_channel_index));
      r_reporter_channel_forced       <= m_trigger_forced(to_integer(w_reporter_channel_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_reporter_mem_result_valid <= r3_read_valid and not(r3_read_req.read_valid);
      r_reporter_mem_result_last  <= r3_read_reporter_last;
      r_reporter_mem_result_data  <= w3_mem_rd_data;
    end if;
  end process;

  i_reporter : entity ecm_lib.ecm_drfm_reporter
  generic map (
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH,
    MEM_WIDTH       => MEM_WIDTH
  )
  port map (
    Clk_axi                 => Clk_axi,
    Clk                     => Clk,
    Rst                     => r_rst,

    Dwell_active            => r_dwell_active,
    Dwell_start             => r_dwell_start,
    Dwell_done              => r_dwell_done,
    Dwell_report_enable     => r_dwell_report_enable,
    Dwell_sequence_num      => r_dwell_sequence_num,

    Channel_report_pending  => r_channel_report_pending,
    Channel_was_read        => r_channel_was_read,
    Channel_was_written     => r_channel_was_written,

    Channel_index           => w_reporter_channel_index,
    Channel_timestamp       => r_reporter_channel_timestamp,
    Channel_seq_num         => r_reporter_channel_seq_num,
    Channel_addr_first      => r_reporter_channel_addr_first,
    Channel_addr_last       => r_reporter_channel_addr_last,
    Channel_max_iq_bits     => r_reporter_channel_max_iq_bits,
    Channel_forced          => r_reporter_channel_forced,

    Read_valid              => w_reporter_mem_read_valid,
    Read_last               => w_reporter_mem_read_last,
    Read_addr               => w_reporter_mem_read_addr,
    Read_result_valid       => r_reporter_mem_result_valid,
    Read_result_last        => r_reporter_mem_result_last,
    Read_result_data        => r_reporter_mem_result_data,

    Channel_reports_done    => w_channel_reports_done,
    Dwell_reports_done      => Dwell_reports_done,


    Axis_ready              => Axis_ready,
    Axis_valid              => Axis_valid,
    Axis_data               => Axis_data,
    Axis_last               => Axis_last,

    Error_timeout           => Error_reporter_timeout,
    Error_overflow          => Error_reporter_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_ext_read_overflow <= r0_read_req.read_valid and Read_req.read_valid;
      Error_int_read_overflow <= w_reporter_mem_read_valid and r_reporter_mem_read_valid and Read_req.read_valid;
      Error_invalid_read      <= r0_read_req.read_valid and not(r_channel_was_written(to_integer(r0_read_req.channel_index)));
    end if;
  end process;

end architecture rtl;
