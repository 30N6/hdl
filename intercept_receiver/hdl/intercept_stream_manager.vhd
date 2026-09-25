library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_stream_manager is
generic (
  DATA_WIDTH : natural
);
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Config_valid            : in  std_logic;
  Config_index            : in  unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  Config_data             : in  intercept_message_stream_encoder_stream_control_t;

  Stream_slot_valid       : out std_logic;
  Stream_slot_index       : out unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  Stream_slot_ack         : in  std_logic;

  Stream_release_valid    : in  std_logic;
  Stream_release_index    : in  unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0)
);
end entity intercept_stream_manager;

architecture rtl of intercept_stream_manager is

  --signal m_stream_control               : intercept_message_stream_encoder_stream_control_array_t(INTERCEPT_NUM_STREAMS - 1 downto 0);
  --signal w_stream_control_wr_en         : std_logic;
  --signal w_stream_control_wr_index      : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  --signal w_stream_control_wr_data       : intercept_message_stream_encoder_stream_control_t;
  --signal r_stream_clear_index           : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0)   := (others => '0');

  signal r_stream_enable            : std_logic_vector(INTERCEPT_NUM_STREAMS - 1 downto 0);
  signal r_stream_active            : std_logic_vector(INTERCEPT_NUM_STREAMS - 1 downto 0);
  signal w_stream_allowed           : std_logic_vector(INTERCEPT_NUM_STREAMS - 1 downto 0);
  signal r_stream_slot_index        : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  signal r_stream_slot_valid        : std_logic;

begin

  --process(Clk)
  --begin
  --  if rising_edge(Clk) then
  --    r_stream_clear_index  <= r_stream_clear_index + 1;
  --  end if;
  --end process;
  --
  --process(all)
  --begin
  --  if rising_edge(all) then
  --    if (Rst = '1') then
  --      w_stream_control_wr_en    <= '1';
  --      w_stream_control_wr_index <= r_stream_clear_index;
  --      w_stream_control_wr_data  <= (enable => '0', others => (others => '-'));
  --    else
  --      w_stream_control_wr_en    <= Config_valid;
  --      w_stream_control_wr_index <= Config_index;
  --      w_stream_control_wr_data  <= Config_data;
  --    end if;
  --  end if;
  --end process;
  --
  --process(Clk)
  --begin
  --  if rising_edge(Clk) then
  --    if (w_stream_control_wr_en = '1') then
  --      m_stream_control(to_integer(w_stream_control_wr_index)) <= w_stream_control_wr_data;
  --    end if;
  --  end if;
  --end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_stream_enable <= (others => '0');
      else
        if (Config_valid = '1') then
          r_stream_enable(to_integer(Config_index)) <= Config_data.enable;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_stream_active <= (others => '0');
      else
        if ((r_stream_slot_valid = '1') and (Stream_slot_ack = '1')) then
          r_stream_active(to_integer(r_stream_slot_index)) <= '1';
        end if;

        if (Stream_release_valid = '1') then
          r_stream_active(to_integer(Stream_release_index)) <= '0';
        end if;
      end if;
    end if;
  end process;

  w_stream_allowed <= r_stream_enable and not(r_stream_active);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_stream_slot_valid <= '0';
        r_stream_slot_index <= (others => '-');
      else
        if (Stream_slot_ack = '1') then
          r_stream_slot_valid <= '0';
          r_stream_slot_index <= (others => '-');
        else
          r_stream_slot_valid <= or_reduce(w_stream_allowed);
          r_stream_slot_index <= first_bit_index(w_stream_allowed);
        end if;
      end if;
    end if;
  end process;

  Stream_slot_valid <= r_stream_slot_valid;
  Stream_slot_index <= r_stream_slot_index;

end architecture rtl;
