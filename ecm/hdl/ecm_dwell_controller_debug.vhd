library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;
  use ecm_lib.ecm_debug_pkg.all;

library mem_lib;

entity ecm_dwell_controller_debug is
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Debug_dwell_controller  : in  ecm_dwell_controller_debug_t;
  Debug_dwell_trigger     : in  ecm_dwell_trigger_debug_t
);
end entity ecm_dwell_controller_debug;

architecture rtl of ecm_dwell_controller_debug is

  constant FIFO_DEPTH                     : natural := 1024;
  constant DEBUG_COMBINED_WIDTH           : natural := ECM_DWELL_CONTROLLER_DEBUG_WIDTH; --ECM_DWELL_TRIGGER_DEBUG_WIDTH + ECM_DWELL_CONTROLLER_DEBUG_WIDTH;

  signal r_debug_dwell_controller         : ecm_dwell_controller_debug_t;
  signal r_debug_dwell_controller_d       : ecm_dwell_controller_debug_t;
  signal r_debug_dwell_trigger            : ecm_dwell_trigger_debug_t;

  signal w_debug_dwell_controller_packed  : std_logic_vector(ECM_DWELL_CONTROLLER_DEBUG_WIDTH - 1 downto 0);
  signal w_debug_dwell_trigger_packed     : std_logic_vector(ECM_DWELL_TRIGGER_DEBUG_WIDTH - 1 downto 0);

  signal r_fifo_wr_en                     : std_logic;
  signal r_fifo_wr_data                   : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_rd_en                     : std_logic;
  signal w_fifo_rd_data                   : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_empty                     : std_logic;

  signal w_fifo_debug_dwell_controller    : std_logic_vector(ECM_DWELL_CONTROLLER_DEBUG_WIDTH - 1 downto 0);
  signal w_fifo_debug_dwell_trigger       : std_logic_vector(ECM_DWELL_TRIGGER_DEBUG_WIDTH - 1 downto 0);

  signal w_unpacked_dwell_controller                  : ecm_dwell_controller_debug_t;
  signal w_unpacked_dwell_trigger                     : ecm_dwell_trigger_debug_t;
  signal w_unpacked_dwell_controller_program_entry_0  : ecm_channel_tx_program_entry_t;
  signal w_unpacked_dwell_trigger_program_entry_0     : ecm_channel_tx_program_entry_t;

  attribute MARK_DEBUG                                                  : string;
  attribute DONT_TOUCH                                                  : string;
  attribute MARK_DEBUG of w_fifo_rd_en                                  : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_rd_en                                  : signal is "TRUE";
  attribute MARK_DEBUG of w_unpacked_dwell_controller                   : signal is "TRUE";
  attribute DONT_TOUCH of w_unpacked_dwell_controller                   : signal is "TRUE";
  --attribute MARK_DEBUG of w_unpacked_dwell_trigger                      : signal is "TRUE";
  --attribute DONT_TOUCH of w_unpacked_dwell_trigger                      : signal is "TRUE";
  attribute MARK_DEBUG of w_unpacked_dwell_controller_program_entry_0   : signal is "TRUE";
  attribute DONT_TOUCH of w_unpacked_dwell_controller_program_entry_0   : signal is "TRUE";
  --attribute MARK_DEBUG of w_unpacked_dwell_trigger_program_entry_0      : signal is "TRUE";
  --attribute DONT_TOUCH of w_unpacked_dwell_trigger_program_entry_0      : signal is "TRUE";

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_debug_dwell_controller    <= Debug_dwell_controller;
      r_debug_dwell_trigger       <= Debug_dwell_trigger;

      r_debug_dwell_controller_d  <= r_debug_dwell_controller;
    end if;
  end process;

  w_debug_dwell_controller_packed <= pack(r_debug_dwell_controller);
  w_debug_dwell_trigger_packed    <= pack(r_debug_dwell_trigger);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_wr_en <= to_stdlogic(r_debug_dwell_controller.s_state /= r_debug_dwell_controller_d.s_state) or
                      r_debug_dwell_controller.w_channel_entry_valid or
                      r_debug_dwell_controller.w_tx_instruction_valid or
                      r_debug_dwell_controller.r_dwell_program_valid or
                      r_debug_dwell_controller.r_dwell_done_meas or
                      r_debug_dwell_controller.r_dwell_done_total or
                      r_debug_dwell_controller.r_dwell_meas_flush_done or
                      r_debug_dwell_controller.r_dwell_start_meas or
                      r_debug_dwell_controller.w_trigger_immediate_tx or
                      r_debug_dwell_controller.w_tx_program_req_valid; --or
                      --r_debug_dwell_trigger.r3_channel_state_wr_en;

      --r_fifo_wr_data <= w_debug_dwell_trigger_packed & w_debug_dwell_controller_packed;
      r_fifo_wr_data <= w_debug_dwell_controller_packed;
    end if;
  end process;

  w_fifo_rd_en <= not(w_fifo_empty);

  i_fifo : entity mem_lib.xpm_async_fifo
  generic map (
    FIFO_DEPTH => FIFO_DEPTH,
    FIFO_WIDTH => DEBUG_COMBINED_WIDTH
  )
  port map (
    Clk_wr        => Clk,
    Clk_rd        => Clk_axi,
    Rst_wr        => Rst,

    Wr_en         => r_fifo_wr_en,
    Wr_data       => r_fifo_wr_data,
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_fifo_rd_en,
    Rd_data       => w_fifo_rd_data,
    Empty         => w_fifo_empty,

    Overflow      => open,
    Underflow     => open
  );

  --(w_fifo_debug_dwell_trigger, w_fifo_debug_dwell_controller) <= w_fifo_rd_data;
  w_fifo_debug_dwell_controller <= w_fifo_rd_data;

  w_unpacked_dwell_controller <= unpack(w_fifo_debug_dwell_controller);
  --w_unpacked_dwell_trigger     <= unpack(w_fifo_debug_dwell_trigger);

  w_unpacked_dwell_controller_program_entry_0    <= unpack(w_unpacked_dwell_controller.w_channel_entry_program_entry_0);
  --w_unpacked_dwell_trigger_program_entry_0       <= unpack(w_unpacked_dwell_trigger.r3_channel_control_program_entry_0);

end architecture rtl;
