library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_dwell_controller_config_decoder is
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Module_config : in  intercept_config_data_t;

  Control_valid : out std_logic;
  Control_data  : out intercept_message_dwell_controller_control_t
);
end entity intercept_dwell_controller_config_decoder;

architecture rtl of intercept_dwell_controller_config_decoder is

  constant NUM_WORDS_DWELL_CONTROLLER_CONTROL : natural := maximum((INTERCEPT_MESSAGE_DWELL_CONTROLLER_CONTROL_ALIGNED_WIDTH + 31) / 32, 2);
  constant WORD_INDEX_WIDTH                   : natural := clog2(NUM_WORDS_DWELL_CONTROLLER_CONTROL);

  type state_t is
  (
    S_IDLE,
    S_MESSAGE
  );

  type message_type_t is
  (
    DWELL_CONTROLLER_CONTROL,
    INVALID
  );

  signal s_state                  : state_t;

  signal r_module_config          : intercept_config_data_t;
  signal w_module_id_match        : std_logic;
  signal w_message_type_match     : std_logic;

  signal r_packed_data            : std_logic_vector(32 * NUM_WORDS_DWELL_CONTROLLER_CONTROL - 1 downto 0);
  signal r_packed_index           : unsigned(WORD_INDEX_WIDTH - 1 downto 0);
  signal r_message_active         : std_logic;
  signal r_message_type           : message_type_t;
  signal r_message_word_length    : unsigned(WORD_INDEX_WIDTH - 1 downto 0);

  signal w_message_done           : std_logic;
  signal r_message_done           : std_logic;

begin

  assert (INTERCEPT_COMMON_HEADER_WIDTH mod 32 = 0)
    report "Packed header width must be a multiple of 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_module_config <= Module_config;
    end if;
  end process;

  w_module_id_match     <= to_stdlogic(r_module_config.module_id = INTERCEPT_MODULE_ID_DWELL_CONTROLLER);
  w_message_type_match  <= to_stdlogic(r_module_config.message_type = INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_CONTROLLER_CONFIG);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_IDLE;
      else
        if (r_module_config.valid = '1') then
          case s_state is
          when S_IDLE =>
            if ((r_module_config.first = '1') and (w_module_id_match = '1') and (w_message_type_match = '1')) then
              s_state <= S_MESSAGE;
            else
              s_state <= S_IDLE;
            end if;

          when S_MESSAGE =>
            if (w_message_done = '1') then
              s_state <= S_IDLE;
            else
              s_state <= S_MESSAGE;
            end if;
          end case;

          if (r_module_config.last = '1') then
            s_state <= S_IDLE;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_message_active <= '0';
        r_packed_index  <= to_unsigned(1, r_packed_index'length);
        r_packed_data   <= (others => '-');
      else
        if (s_state = S_IDLE) then
          r_message_active            <= r_module_config.valid and r_module_config.first and w_module_id_match and w_message_type_match;
          r_packed_data(31 downto 0)  <= r_module_config.data;
          r_packed_index              <= to_unsigned(1, r_packed_index'length);
        elsif ((r_message_active = '1') and (r_module_config.valid = '1')) then
          r_packed_data(32*to_integer(r_packed_index) + 31 downto 32*to_integer(r_packed_index)) <= r_module_config.data;

          if (r_packed_index = (r_message_word_length - 1)) then
            r_message_active  <= '0';
            r_packed_index    <= to_unsigned(1, r_packed_index'length);
          else
            r_packed_index    <= r_packed_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        if (r_module_config.message_type = INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_CONTROLLER_CONFIG) then
          r_message_type        <= DWELL_CONTROLLER_CONTROL;
          r_message_word_length <= to_unsigned(NUM_WORDS_DWELL_CONTROLLER_CONTROL, r_message_word_length'length);
        else
          r_message_type        <= INVALID;
          r_message_word_length <= to_unsigned(2, r_message_word_length'length);
        end if;
      end if;
    end if;
  end process;

  w_message_done <= r_message_active and r_module_config.valid and to_stdlogic(r_packed_index = (r_message_word_length - 1));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_message_done <= w_message_done;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Control_valid <= r_message_done and to_stdlogic(r_message_type = DWELL_CONTROLLER_CONTROL);
      Control_data  <= unpack_aligned(r_packed_data(INTERCEPT_MESSAGE_DWELL_CONTROLLER_CONTROL_ALIGNED_WIDTH - 1 downto 0));
    end if;
  end process;

end architecture rtl;
