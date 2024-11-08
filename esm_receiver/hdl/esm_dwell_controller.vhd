library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_dwell_controller is
generic (
  PLL_PRE_LOCK_DELAY_CYCLES   : natural;
  PLL_POST_LOCK_DELAY_CYCLES  : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Module_config       : in  esm_config_data_t;

  Ad9361_control      : out std_logic_vector(3 downto 0);
  Ad9361_status       : in  std_logic_vector(7 downto 0);

  Dwell_active        : out std_logic;
  Dwell_data          : out esm_dwell_metadata_t;
  Dwell_sequence_num  : out unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0)
);
end entity esm_dwell_controller;

architecture rtl of esm_dwell_controller is

  type state_t is
  (
    S_IDLE,
    S_INSTRUCTION_LOOKUP,
    S_ENTRY_LOOKUP,
    S_PLL_WAIT_PRE_LOCK,
    S_PLL_WAIT_POST_LOCK,
    S_START_WAIT,
    S_DWELL_ACTIVE,
    S_DWELL_DONE
  );

  --constant PLL_PRE_LOCK_DELAY_CYCLES  : natural := 2048;
  --constant PLL_POST_LOCK_DELAY_CYCLES : natural := 4096;

  signal s_state                    : state_t;

  signal r_rst                      : std_logic;
  signal r_timestamp                : unsigned(63 downto 0);
  signal r_ad9361_status            : std_logic_vector(7 downto 0);

  signal w_dwell_entry_valid        : std_logic;
  signal w_dwell_entry_index        : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal w_dwell_entry_data         : esm_dwell_metadata_t;

  signal w_dwell_instruction_valid  : std_logic;
  signal w_dwell_instruction_index  : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  signal w_dwell_instruction_data   : esm_dwell_instruction_t;

  signal w_dwell_program_valid      : std_logic;
  signal w_dwell_program_data       : esm_message_dwell_program_header_t;

  signal m_dwell_entry              : esm_dwell_metadata_array_t(ESM_NUM_DWELL_ENTRIES - 1 downto 0);
  signal m_dwell_instruction        : esm_dwell_instruction_array_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
  signal r_dwell_program_data       : esm_message_dwell_program_header_t;
  signal r_dwell_program_valid      : std_logic;

  signal r_pll_pre_lock_cycles      : unsigned(clog2(PLL_PRE_LOCK_DELAY_CYCLES) - 1 downto 0);
  signal r_pll_pre_lock_done        : std_logic;
  signal r_pll_post_lock_cycles     : unsigned(clog2(PLL_POST_LOCK_DELAY_CYCLES) - 1 downto 0);
  signal r_pll_post_lock_done       : std_logic;

  signal w_instructions_done        : std_logic;
  signal w_pll_pre_lock_done        : std_logic;
  signal w_pll_locked               : std_logic;
  signal w_pll_post_lock_done       : std_logic;
  signal r_dwell_done               : std_logic;

  signal r_dwell_start_time_check   : std_logic;
  signal w_delay_start              : std_logic;

  signal r_global_counter           : unsigned(31 downto 0);
  signal r_global_counter_is_zero   : std_logic;
  signal r_dwell_cycles             : unsigned(31 downto 0);
  signal r_dwell_repeat             : unsigned(3 downto 0);
  signal r_instruction_index        : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  signal r_instruction_data         : esm_dwell_instruction_t;
  signal r_dwell_entry              : esm_dwell_metadata_t;
  signal r_dwell_entry_d            : esm_dwell_metadata_t;
  signal r_dwell_active             : std_logic;
  signal r_dwell_sequence_num       : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst           <= Rst;
      r_ad9361_status <= Ad9361_status;
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

  i_config : entity esm_lib.esm_dwell_config_decoder
  port map (
    Clk                     => Clk,
    Rst                     => r_rst,

    Module_config           => Module_config,

    Dwell_entry_valid       => w_dwell_entry_valid,
    Dwell_entry_index       => w_dwell_entry_index,
    Dwell_entry_data        => w_dwell_entry_data,

    Dwell_instruction_valid => w_dwell_instruction_valid,
    Dwell_instruction_index => w_dwell_instruction_index,
    Dwell_instruction_data  => w_dwell_instruction_data,

    Dwell_program_valid     => w_dwell_program_valid,
    Dwell_program_data      => w_dwell_program_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_dwell_entry_valid = '1') then
        m_dwell_entry(to_integer(w_dwell_entry_index)) <= w_dwell_entry_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_dwell_instruction_valid = '1') then
        m_dwell_instruction(to_integer(w_dwell_instruction_index)) <= w_dwell_instruction_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_program_data.enable_program        <= '0';
        r_dwell_program_data.enable_delayed_start  <= '-';
        r_dwell_program_data.global_counter_init   <= (others => '-');
        r_dwell_program_data.delayed_start_time    <= (others => '-');
      else
        if (w_dwell_program_valid = '1') then
          r_dwell_program_data <= w_dwell_program_data;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_program_valid <= w_dwell_program_valid;
    end if;
  end process;

  w_instructions_done   <= not(r_instruction_data.valid) or (r_instruction_data.global_counter_check and r_global_counter_is_zero);
  w_pll_pre_lock_done   <= r_instruction_data.skip_pll_prelock_wait   or r_pll_pre_lock_done;
  w_pll_locked          <= r_instruction_data.skip_pll_lock_check     or r_ad9361_status(6);
  w_pll_post_lock_done  <= r_instruction_data.skip_pll_postlock_wait  or r_pll_post_lock_done;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_start_time_check <= to_stdlogic(r_dwell_program_data.delayed_start_time > r_timestamp);
    end if;
  end process;

  w_delay_start <= r_dwell_program_data.enable_delayed_start and r_dwell_start_time_check;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          s_state <= S_IDLE;  --transition handled below

        when S_INSTRUCTION_LOOKUP =>
          s_state <= S_ENTRY_LOOKUP;

        when S_ENTRY_LOOKUP =>
          if (w_instructions_done = '1') then
            s_state <= S_IDLE;
          else
            s_state <= S_PLL_WAIT_PRE_LOCK;
          end if;

        --TODO: separate FSM for pll checks
        --TODO: skip PLL delays if not changing the fast lock profile

        when S_PLL_WAIT_PRE_LOCK =>
          if ((w_pll_pre_lock_done = '1') and (w_pll_locked = '1')) then
            s_state <= S_PLL_WAIT_POST_LOCK;
          else
            s_state <= S_PLL_WAIT_PRE_LOCK;
          end if;

        when S_PLL_WAIT_POST_LOCK =>
          if (w_pll_post_lock_done = '1') then
            s_state <= S_START_WAIT;
          else
            s_state <= S_PLL_WAIT_POST_LOCK;
          end if;

        when S_START_WAIT =>
          if (w_delay_start = '1') then
            s_state <= S_START_WAIT;
          else
            s_state <= S_DWELL_ACTIVE;
          end if;

        when S_DWELL_ACTIVE =>
          if (r_dwell_done = '1') then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_DWELL_ACTIVE;
          end if;

        when S_DWELL_DONE =>
          if (w_instructions_done = '1') then
            s_state <= S_IDLE;
          elsif (r_dwell_repeat > 0) then
            s_state <= S_ENTRY_LOOKUP;
          else
            s_state <= S_INSTRUCTION_LOOKUP;
          end if;

        end case;

        if (r_dwell_program_valid = '1') then --TODO: check this in s_idle instead?
          s_state <= S_INSTRUCTION_LOOKUP;
        elsif ((w_dwell_entry_valid = '1') or (w_dwell_instruction_valid = '1') or (w_dwell_program_valid = '1')) then
          s_state <= S_IDLE;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_global_counter          <= r_dwell_program_data.global_counter_init;
        r_global_counter_is_zero  <= to_stdlogic(r_dwell_program_data.global_counter_init = 0);
        r_instruction_index       <= (others => '0');
      elsif (s_state = S_DWELL_DONE) then
        if (r_instruction_data.global_counter_dec = '1') then
          r_global_counter          <= r_global_counter - 1;
          r_global_counter_is_zero  <= to_stdlogic(r_global_counter = 1);
        end if;

        if (r_dwell_repeat = 0) then
          r_instruction_index <= r_instruction_data.next_instruction_index;
        end if;
      end if;
    end if;
  end process;


  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_INSTRUCTION_LOOKUP) then
        r_dwell_repeat <= m_dwell_instruction(to_integer(r_instruction_index)).repeat_count;
      elsif (s_state = S_DWELL_DONE) then
        r_dwell_repeat <= r_dwell_repeat - 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_ENTRY_LOOKUP) then
        r_pll_pre_lock_cycles <= (others => '0');
        r_pll_pre_lock_done   <= '0';
      else
        r_pll_pre_lock_cycles <= r_pll_pre_lock_cycles + 1;
        r_pll_pre_lock_done   <= to_stdlogic(r_pll_pre_lock_cycles = (PLL_PRE_LOCK_DELAY_CYCLES - 2));
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_PLL_WAIT_PRE_LOCK) then
        r_pll_post_lock_cycles <= (others => '0');
        r_pll_post_lock_done   <= '0';
      else
        r_pll_post_lock_cycles <= r_pll_post_lock_cycles + 1;
        r_pll_post_lock_done   <= to_stdlogic(r_pll_post_lock_cycles = (PLL_POST_LOCK_DELAY_CYCLES - 2));
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_START_WAIT) then
        r_dwell_cycles <= (others => '0');
        r_dwell_done   <= '0';
      else
        r_dwell_cycles <= r_dwell_cycles + 1;
        r_dwell_done   <= to_stdlogic(r_dwell_entry_d.duration = r_dwell_cycles);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_sequence_num <= (others => '0');
      else
        if (s_state = S_DWELL_DONE) then
          r_dwell_sequence_num <= r_dwell_sequence_num + 1;
        end if;
      end if;
    end if;
  end process;


  process(Clk)
  begin
    if rising_edge(Clk) then
      r_instruction_data  <= m_dwell_instruction(to_integer(r_instruction_index));
      r_dwell_entry       <= m_dwell_entry(to_integer(r_instruction_data.entry_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active  <= to_stdlogic(s_state = S_DWELL_ACTIVE);
      r_dwell_entry_d <= r_dwell_entry;
    end if;
  end process;

  Dwell_active        <= r_dwell_active;
  Dwell_data          <= r_dwell_entry_d;
  Dwell_sequence_num  <= r_dwell_sequence_num;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Ad9361_control <= std_logic_vector(r_dwell_entry_d.fast_lock_profile & '0');
    end if;
  end process;

end architecture rtl;
