library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library adsb_lib;
  use adsb_lib.adsb_pkg.all;

entity adsb_reporter is
generic (
  AXI_DATA_WIDTH      : natural;
  PREAMBLE_S_WIDTH    : natural;
  PREAMBLE_SN_WIDTH   : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Crc_filter          : in  std_logic;

  Message_valid       : in  std_logic;
  Message_data        : in  adsb_message_t;
  Message_preamble_s  : in  unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  Message_preamble_sn : in  unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);
  Message_crc_match   : in  std_logic;
  Message_timestamp   : in  timestamp_t;

  Axis_ready          : in  std_logic;
  Axis_valid          : out std_logic;
  Axis_last           : out std_logic;
  Axis_data           : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0)
);
end entity adsb_reporter;

architecture rtl of adsb_reporter is

  constant REPORT_TRANSFER_COUNT  : natural := (ADSB_REPORT_WIDTH + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH;
  constant REPORT_PADDED_WIDTH    : natural := REPORT_TRANSFER_COUNT * AXI_DATA_WIDTH;

  signal r_crc_filter           : std_logic;
  signal w_message_valid        : std_logic;

  signal r_sequence_num         : unsigned(31 downto 0);

  signal r_report_pending       : std_logic := '0';
  signal r_report_word_index    : unsigned(clog2(REPORT_TRANSFER_COUNT) - 1 downto 0);
  signal w_report_data          : adsb_report_t;
  signal r_report_packed        : std_logic_vector(ADSB_REPORT_WIDTH - 1 downto 0);

  signal w_padded_message       : std_logic_vector(w_report_data.message_data'length - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_crc_filter <= Crc_filter;
    end if;
  end process;

  w_message_valid <= Message_valid and (not(r_crc_filter) or Message_crc_match);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_sequence_num <= (others => '0');
      else
        if (w_message_valid = '1') then
          r_sequence_num <= r_sequence_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_report_pending    <= '0';
        r_report_word_index <= (others => '-');
      else
        if (r_report_pending = '0') then
          if (w_message_valid = '1') then
            r_report_pending  <= '1';
          end if;
          r_report_word_index <= (others => '0');
        elsif (Axis_ready = '1') then
          if (r_report_word_index < (REPORT_TRANSFER_COUNT - 1)) then
            r_report_pending    <= '1';
            r_report_word_index <= r_report_word_index + 1;
          else
            r_report_pending    <= '0';
            r_report_word_index <= (others => '-');
          end if;
        end if;
      end if;
    end if;
  end process;

  w_padded_message <= Message_data & x"0000";

  process(all)
  begin
    w_report_data.magic_num     <= ADSB_REPORT_MAGIC_NUM;
    w_report_data.sequence_num  <= r_sequence_num;
    w_report_data.timestamp     <= Message_timestamp;
    w_report_data.preamble_s    <= resize_up(Message_preamble_s, w_report_data.preamble_s'length);
    w_report_data.preamble_sn   <= resize_up(Message_preamble_sn, w_report_data.preamble_sn'length);
    w_report_data.message_crc   <= (0 => Message_crc_match, others => '0');
    w_report_data.message_data  <= byteswap(w_padded_message, AXI_DATA_WIDTH);
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_report_pending = '0') then
        r_report_packed <= pack(w_report_data);
      elsif (Axis_ready = '1') then
        r_report_packed <= shift_right(r_report_packed, AXI_DATA_WIDTH);
      end if;
    end if;
  end process;

  Axis_valid <= r_report_pending;
  Axis_last  <= to_stdlogic(r_report_word_index = (REPORT_TRANSFER_COUNT - 1));
  Axis_data  <= r_report_packed(AXI_DATA_WIDTH - 1 downto 0);

end architecture rtl;
