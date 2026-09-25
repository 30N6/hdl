library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_dwell_controller is
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Module_config : in  intercept_config_data_t;

  Dwell_data    : out intercept_dwell_data_t;
  Dwell_active  : out std_logic
);
end entity intercept_dwell_controller;

architecture rtl of intercept_dwell_controller is

  signal r_rst            : std_logic;
  signal r_module_config  : intercept_config_data_t;

  signal w_control_valid  : std_logic;
  signal w_control_data   : intercept_message_dwell_controller_control_t;

  signal r_dwell_active   : std_logic;
  signal r_dwell_data     : intercept_dwell_data_t;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst           <= Rst;
      r_module_config <= Module_config;
    end if;
  end process;

  i_config : entity intercept_lib.intercept_dwell_controller_config_decoder
  port map (
    Clk           => Clk,
    Rst           => r_rst,

    Module_config => r_module_config,

    Control_valid => w_control_valid,
    Control_data  => w_control_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_active  <= '0';
        r_dwell_data    <= (sequence_num => (others => '0'), others => (others => '-'));
      else
        if (w_control_valid = '1') then
          r_dwell_active                <= w_control_data.enable;
          r_dwell_data.frequency        <= w_control_data.dwell_frequency;
          r_dwell_data.tag              <= w_control_data.dwell_tag;
          r_dwell_data.window_duration  <= maximum(w_control_data.window_duration, INTERCEPT_DWELL_DURATION_MIN_FRAMES);

          if (w_control_data.enable = '1') then
            r_dwell_data.sequence_num <= r_dwell_data.sequence_num + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  Dwell_data    <= r_dwell_data;
  Dwell_active  <= r_dwell_active and not(w_control_valid);

end architecture rtl;
