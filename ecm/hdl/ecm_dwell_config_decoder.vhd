library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

entity ecm_dwell_config_decoder is
port (
  Clk                         : in  std_logic;
  Rst                         : in  std_logic;

  Module_config               : in  ecm_config_data_t;

  Dwell_program_valid         : out std_logic;
  Dwell_program_data          : out ecm_dwell_program_entry_t;

  Dwell_entry_valid           : out std_logic;
  Dwell_entry_index           : out unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  Dwell_entry_data            : out ecm_dwell_entry_t;

  Dwell_channel_entry_valid   : out std_logic;
  Dwell_channel_entry_index   : out unsigned(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
  Dwell_channel_entry_data    : out ecm_channel_control_entry_t;

  Dwell_tx_instruction_valid  : out std_logic;
  Dwell_tx_instruction_index  : out unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  Dwell_tx_instruction_data   : out std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)
);
end entity ecm_dwell_config_decoder;

architecture rtl of ecm_dwell_config_decoder is

  constant NUM_WORDS_DWELL_PROGRAM  : natural := ECM_DWELL_PROGRAM_ENTRY_ALIGNED_WIDTH / 32;
  constant NUM_WORDS_DWELL_ENTRY    : natural := ECM_DWELL_ENTRY_ALIGNED_WIDTH / 32;
  constant NUM_WORDS_CHANNEL_ENTRY  : natural := ECM_CHANNEL_CONTROL_ENTRY_ALIGNED_WIDTH / 32;
  constant NUM_WORDS_TX_INSTRUCTION : natural := ECM_TX_INSTRUCTION_DATA_WIDTH / 32;
  constant NUM_WORDS_MAX            : natural := NUM_WORDS_DWELL_ENTRY; --maximum(NUM_WORDS_DWELL_PROGRAM & NUM_WORDS_DWELL_ENTRY & NUM_WORDS_CHANNEL_ENTRY & NUM_WORDS_TX_INSTRUCTION);
  constant WORD_INDEX_WIDTH         : natural := clog2(NUM_WORDS_MAX);

  type state_t is
  (
    S_IDLE,
    S_MESSAGE
  );

  type message_type_t is
  (
    DWELL_PROGRAM,
    DWELL_ENTRY,
    CHANNEL_ENTRY,
    TX_INSTRUCTION,
    INVALID
  );

  signal s_state                  : state_t;

  signal r_module_config          : ecm_config_data_t;
  signal w_module_id_match        : std_logic;
  signal w_message_type_match     : std_logic;

  signal r_packed_data            : std_logic_vector(32 * NUM_WORDS_MAX - 1 downto 0);
  signal r_packed_index           : unsigned(WORD_INDEX_WIDTH - 1 downto 0);
  signal r_message_active         : std_logic;
  signal r_message_type           : message_type_t;
  signal r_message_word_length    : unsigned(WORD_INDEX_WIDTH - 1 downto 0);

  signal w_message_done           : std_logic;
  signal r_message_done           : std_logic;
  signal r_address                : unsigned(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0);

begin

  assert (ECM_COMMON_HEADER_WIDTH mod 32 = 0)
    report "Packed header width must be a multiple of 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_module_config <= Module_config;
    end if;
  end process;

  w_module_id_match     <= to_stdlogic(r_module_config.module_id = ECM_MODULE_ID_DWELL_CONTROLLER);
  w_message_type_match  <= to_stdlogic(r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM) or
                           to_stdlogic(r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY) or
                           to_stdlogic(r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_CHANNEL_CONTROL) or
                           to_stdlogic(r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_TX_INSTRUCTION);

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
          r_message_active            <= r_module_config.valid and r_module_config.first;
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
        r_address <= r_module_config.address;

        if (r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM) then
          r_message_type        <= DWELL_PROGRAM;
          r_message_word_length <= to_unsigned(NUM_WORDS_DWELL_PROGRAM, r_message_word_length'length);

        elsif (r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY) then
          r_message_type        <= DWELL_ENTRY;
          r_message_word_length <= to_unsigned(NUM_WORDS_DWELL_ENTRY, r_message_word_length'length);

        elsif (r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_CHANNEL_CONTROL) then
          r_message_type        <= CHANNEL_ENTRY;
          r_message_word_length <= to_unsigned(NUM_WORDS_CHANNEL_ENTRY, r_message_word_length'length);

        elsif (r_module_config.message_type = ECM_CONTROL_MESSAGE_TYPE_DWELL_TX_INSTRUCTION) then
          r_message_type        <= TX_INSTRUCTION;
          r_message_word_length <= to_unsigned(NUM_WORDS_TX_INSTRUCTION, r_message_word_length'length);

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
      Dwell_program_valid         <= r_message_done and to_stdlogic(r_message_type = DWELL_PROGRAM);
      Dwell_program_data          <= unpack(r_packed_data(ECM_DWELL_PROGRAM_ENTRY_ALIGNED_WIDTH - 1 downto 0));

      Dwell_entry_valid           <= r_message_done and to_stdlogic(r_message_type = DWELL_ENTRY);
      Dwell_entry_index           <= r_address(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
      Dwell_entry_data            <= unpack(r_packed_data(ECM_DWELL_ENTRY_ALIGNED_WIDTH - 1 downto 0));

      Dwell_channel_entry_valid   <= r_message_done and to_stdlogic(r_message_type = CHANNEL_ENTRY);
      Dwell_channel_entry_index   <= r_address(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
      Dwell_channel_entry_data    <= unpack(r_packed_data(ECM_CHANNEL_CONTROL_ENTRY_ALIGNED_WIDTH - 1 downto 0));

      Dwell_tx_instruction_valid  <= r_message_done and to_stdlogic(r_message_type = TX_INSTRUCTION);
      Dwell_tx_instruction_index  <= r_address(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
      Dwell_tx_instruction_data   <= r_packed_data(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
    end if;
  end process;

end architecture rtl;
