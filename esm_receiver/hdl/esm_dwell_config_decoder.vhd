library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_dwell_config_decoder is
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Module_config           : in  esm_config_data_t;

  Dwell_entry_valid       : out std_logic;
  Dwell_entry_index       : out unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  Dwell_entry_data        : out esm_dwell_metadata_t;

  Dwell_instruction_valid : out std_logic;
  Dwell_instruction_index : out unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  Dwell_instruction_data  : out esm_dwell_instruction_t;

  Dwell_program_valid     : out std_logic;
  Dwell_program_data      : out esm_message_dwell_program_header_t
);
end entity esm_dwell_config_decoder;

architecture rtl of esm_dwell_config_decoder is

  constant PACKED_HEADER_WIDTH            : natural := maximum(ESM_MESSAGE_DWELL_ENTRY_PACKED_WIDTH, ESM_MESSAGE_DWELL_PROGRAM_HEADER_PACKED_WIDTH);
  constant NUM_HEADER_WORDS               : natural := PACKED_HEADER_WIDTH / 32;
  constant NUM_HEADER_WORDS_DWELL_ENTRY   : natural := ESM_MESSAGE_DWELL_ENTRY_PACKED_WIDTH / 32;
  constant NUM_HEADER_WORDS_DWELL_PROGRAM : natural := ESM_MESSAGE_DWELL_PROGRAM_HEADER_PACKED_WIDTH / 32;

  type state_t is
  (
    S_IDLE,
    S_HEADER,
    S_WAIT_DONE
  );

  type message_type_t is
  (
    DWELL_ENTRY,
    DWELL_PROGRAM
  );

  signal s_state                : state_t;

  signal r_module_config        : esm_config_data_t;
  signal w_module_id_match      : std_logic;
  signal w_message_type_match   : std_logic;

  signal r_packed_data          : std_logic_vector(PACKED_HEADER_WIDTH - 1 downto 0);
  signal r_header_index         : unsigned(clog2(NUM_HEADER_WORDS) - 1 downto 0);
  signal r_header_active        : std_logic;

  signal w_header_done          : std_logic;
  signal r_header_done          : std_logic;

  signal r_message_type         : message_type_t;
  signal r_header_word_length   : unsigned(clog2(NUM_HEADER_WORDS) - 1 downto 0);

  signal r_instruction_index    : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  signal r_instruction_active   : std_logic;

  signal w_dwell_entry          : esm_message_dwell_entry_t;
  signal w_dwell_instruction    : esm_dwell_instruction_t;
  signal w_dwell_program_header : esm_message_dwell_program_header_t;

begin

  assert (PACKED_HEADER_WIDTH mod 32 = 0)
    report "Packed header width must be a multiple of 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_module_config <= Module_config;
    end if;
  end process;

  w_module_id_match     <= to_stdlogic(r_module_config.module_id = ESM_MODULE_ID_CONTROL);
  w_message_type_match  <= to_stdlogic(r_module_config.message_type = ESM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY) or
                           to_stdlogic(r_module_config.message_type = ESM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM);

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
              s_state <= S_HEADER;
            else
              s_state <= S_IDLE;
            end if;

          when S_HEADER =>
            if (w_header_done = '1') then
              s_state <= S_WAIT_DONE;
            else
              s_state <= S_HEADER;
            end if;

          when S_WAIT_DONE =>
            s_state <= S_WAIT_DONE;
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
        r_header_active <= '0';
        r_header_index  <= to_unsigned(1, r_header_index'length);
        r_packed_data   <= (others => '-');
      else
        if (s_state = S_IDLE) then
          r_header_active             <= '1';
          r_packed_data(31 downto 0)  <= r_module_config.data;
          r_header_index              <= to_unsigned(1, r_header_index'length);
        elsif ((r_header_active = '1') and (r_module_config.valid = '1')) then
          r_packed_data(32*to_integer(r_header_index) + 31 downto 32*to_integer(r_header_index)) <= r_module_config.data;

          if (r_header_index = (r_header_word_length - 1)) then
            r_header_active <= '0';
            r_header_index  <= to_unsigned(1, r_header_index'length);
          else
            r_header_index  <= r_header_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        if (r_module_config.message_type = ESM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY) then
          r_message_type        <= DWELL_ENTRY;
          r_header_word_length  <= to_unsigned(NUM_HEADER_WORDS_DWELL_ENTRY, r_header_word_length'length);
        else
          r_message_type        <= DWELL_PROGRAM;
          r_header_word_length  <= to_unsigned(NUM_HEADER_WORDS_DWELL_PROGRAM, r_header_word_length'length);
        end if;
      end if;
    end if;
  end process;

  w_header_done <= r_header_active and r_module_config.valid and to_stdlogic(r_header_index = (r_header_word_length - 1));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_header_done <= w_header_done;
    end if;
  end process;

  w_dwell_entry           <= unpack(r_packed_data(ESM_MESSAGE_DWELL_ENTRY_PACKED_WIDTH - 1 downto 0));
  w_dwell_program_header  <= unpack(r_packed_data(ESM_MESSAGE_DWELL_PROGRAM_HEADER_PACKED_WIDTH - 1 downto 0));
  w_dwell_instruction     <= unpack(r_module_config.data);

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_entry_valid <= r_header_done and to_stdlogic(r_message_type = DWELL_ENTRY);
      Dwell_entry_index <= w_dwell_entry.entry_index;
      Dwell_entry_data  <= w_dwell_entry.entry_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_instruction_index   <= (others => '0');
        r_instruction_active  <= '1';
      elsif ((r_instruction_active = '1') and (r_module_config.valid = '1') and (s_state = S_WAIT_DONE) and (r_message_type = DWELL_PROGRAM)) then
        if (r_instruction_index = (ESM_NUM_DWELL_INSTRUCTIONS - 1)) then
          r_instruction_active  <= '0';
          r_instruction_index   <= (others => '0');
        else
          r_instruction_index   <= r_instruction_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_instruction_valid <= r_module_config.valid and to_stdlogic(s_state = S_WAIT_DONE) and to_stdlogic(r_message_type = DWELL_PROGRAM);
      Dwell_instruction_index <= r_instruction_index;
      Dwell_instruction_data  <= w_dwell_instruction;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_program_valid <= r_module_config.valid and r_module_config.last and to_stdlogic(s_state = S_WAIT_DONE) and to_stdlogic(r_message_type = DWELL_PROGRAM);
      Dwell_program_data  <= w_dwell_program_header;
    end if;
  end process;

end architecture rtl;
