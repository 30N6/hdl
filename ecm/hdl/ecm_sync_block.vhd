library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity ecm_sync_block is
generic (
  DDS_LATENCY   : natural;
  DRFM_LATENCY  : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Sync_dds            : out channelizer_control_t;
  Sync_dwell_to_drfm  : out channelizer_control_t
);
end entity ecm_sync_block;

architecture rtl of ecm_sync_block is

  constant DDS_DELAY  : natural := DRFM_LATENCY - DDS_LATENCY;

  signal r_rst        : std_logic;
  signal r_dds_rst    : std_logic_vector(DDS_DELAY - 1 downto 0);

  signal r_channel_dds  : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_channel_drfm : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_valid_dds    : std_logic;
  signal r_valid_drfm   : std_logic;
  signal r_last_dds     : std_logic;
  signal r_last_drfm    : std_logic;

begin

  assert (DRFM_LATENCY > DDS_LATENCY)
    report "Unsupported configuration"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      for i in 0 to (DDS_DELAY - 1) loop
        if (i = 0) then
          r_dds_rst(i) <= r_rst;
        else
          r_dds_rst(i) <= r_dds_rst(i - 1);
        end if;
      end loop;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_channel_drfm  <= (others => '0');
        r_valid_drfm    <= '0';
        r_last_drfm   <= '-';
      else
        r_valid_drfm <= not(r_valid_drfm);
        if (r_valid_drfm = '1') then
          r_channel_drfm <= r_channel_drfm + 1;
          r_last_drfm    <= to_stdlogic(r_channel_drfm = (ECM_NUM_CHANNELS - 2));
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_dds_rst(DDS_DELAY - 1) = '1') then
        r_channel_dds <= (others => '0');
        r_valid_dds   <= '0';
        r_last_dds    <= '-';
      else
        r_valid_dds <= not(r_valid_dds);
        if (r_valid_dds = '1') then
          r_channel_dds <= r_channel_dds + 1;
          r_last_dds    <= to_stdlogic(r_channel_dds = (ECM_NUM_CHANNELS - 2));
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Sync_dds.valid                <= r_valid_dds;
      Sync_dds.last                 <= r_last_dds;
      Sync_dds.data_index           <= resize_up(r_channel_dds, Sync_dds.data_index'length);

      Sync_dwell_to_drfm.valid      <= r_valid_drfm;
      Sync_dwell_to_drfm.last       <= r_last_drfm;
      Sync_dwell_to_drfm.data_index <= resize_up(r_channel_drfm, Sync_dwell_to_drfm.data_index'length);
    end if;
  end process;

end architecture rtl;
