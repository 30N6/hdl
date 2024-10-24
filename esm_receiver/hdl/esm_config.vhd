library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_config is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Axis_ready    : out std_logic;
  Axis_valid    : in  std_logic;
  Axis_last     : in  std_logic;
  Axis_data     : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  Rst_out       : out std_logic;
  Enable_status : out std_logic;
  Enable_chan   : out std_logic_vector(1 downto 0);
  Enable_pdw    : out std_logic_vector(1 downto 0);

  Module_config : out esm_config_data_t
);
end entity esm_config;

architecture rtl of esm_config is

  type state_t is
  (
    S_WORD_0,
    S_WORD_1,
    S_WORD_2,
    S_DROP,
    S_ACTIVE_CONFIG_CONTROL,
    S_ACTIVE_CONFIG_MODULE
  );

  signal r_axis_valid     : std_logic;
  signal r_axis_last      : std_logic;
  signal r_axis_data      : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal s_state          : state_t;

  signal w_module_id      : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
  signal w_message_type   : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  signal r_module_id      : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
  signal r_message_type   : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  signal r_first          : std_logic;

  signal r_module_config  : esm_config_data_t;

begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI data width expected to be 32."
    severity failure;

  Axis_ready <= '1';

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_axis_valid  <= Axis_valid;
      r_axis_last   <= Axis_last;
      r_axis_data   <= Axis_data;
    end if;
  end process;

  w_module_id     <= unsigned(r_axis_data(24 + ESM_MODULE_ID_WIDTH - 1 downto 24));
  w_message_type  <= unsigned(r_axis_data(16 + ESM_MESSAGE_TYPE_WIDTH - 1 downto 16));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_WORD_0;
      else
        if (r_axis_valid = '1') then
          case s_state is
          when S_WORD_0 =>
            if (r_axis_data = ESM_CONTROL_MAGIC_NUM) then
              s_state <= S_WORD_1;
            else
              s_state <= S_DROP;
            end if;

          when S_WORD_1 =>
            s_state <= S_WORD_2;

          when S_WORD_2 =>
            if (w_module_id = ESM_MODULE_ID_CONTROL) then
              s_state <= S_ACTIVE_CONFIG_CONTROL;
            else
              s_state <= S_ACTIVE_CONFIG_MODULE;
            end if;

          when S_DROP =>
            s_state <= S_DROP;

          when S_ACTIVE_CONFIG_CONTROL =>
            s_state <= S_ACTIVE_CONFIG_CONTROL;

          when S_ACTIVE_CONFIG_MODULE =>
            s_state <= S_ACTIVE_CONFIG_MODULE;

          end case;

          if (r_axis_last = '1') then
            s_state <= S_WORD_0;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_WORD_2) then
        r_module_id     <= w_module_id;
        r_message_type  <= w_message_type;
      end if;

      if (r_axis_valid = '1') then
        r_first <= to_stdlogic(s_state = S_WORD_2);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_module_config.valid         <= r_axis_valid and to_stdlogic(s_state = S_ACTIVE_CONFIG_MODULE);
      r_module_config.first         <= r_first;
      r_module_config.last          <= r_axis_last;
      r_module_config.data          <= r_axis_data;
      r_module_config.module_id     <= r_module_id;
      r_module_config.message_type  <= r_message_type;
    end if;
  end process;

  Module_config <= r_module_config;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        Rst_out       <= '0';
        Enable_chan   <= (others => '0');
        Enable_pdw    <= (others => '0');
        Enable_status <= '0';
      else
        if ((r_axis_valid = '1') and (s_state = S_ACTIVE_CONFIG_CONTROL) and (r_first = '1') and (r_message_type = ESM_CONTROL_MESSAGE_TYPE_ENABLE)) then
          Rst_out       <= r_axis_data(24);
          Enable_chan   <= r_axis_data(17 downto 16);
          Enable_pdw    <= r_axis_data(9 downto 8);
          Enable_status <= r_axis_data(0);
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
