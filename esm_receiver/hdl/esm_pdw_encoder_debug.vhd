library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;
  use esm_lib.esm_debug_pkg.all;

library mem_lib;

entity esm_pdw_encoder_debug is
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Debug_sample_processor  : in  esm_pdw_sample_processor_debug_t;
  Debug_pdw_encoder       : in  esm_pdw_encoder_debug_t
);
end entity esm_pdw_encoder_debug;

architecture rtl of esm_pdw_encoder_debug is

  constant FIFO_DEPTH                     : natural := 1024;
  constant DEBUG_COMBINED_WIDTH           : natural := ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH + ESM_PDW_ENCODER_DEBUG_WIDTH;

  signal r_debug_sample_processor         : esm_pdw_sample_processor_debug_t;
  signal r_debug_pdw_encoder              : esm_pdw_encoder_debug_t;

  signal w_debug_sample_processor_packed  : std_logic_vector(ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH - 1 downto 0);
  signal w_debug_pdw_encoder_packed       : std_logic_vector(ESM_PDW_ENCODER_DEBUG_WIDTH - 1 downto 0);

  signal r_fifo_wr_en                     : std_logic;
  signal r_fifo_wr_data                   : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_rd_en                     : std_logic;
  signal w_fifo_rd_data                   : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_empty                     : std_logic;

  signal w_fifo_debug_sample_processor    : std_logic_vector(ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH - 1 downto 0);
  signal w_fifo_debug_pdw_encoder         : std_logic_vector(ESM_PDW_ENCODER_DEBUG_WIDTH - 1 downto 0);

  signal w_unpacked_sample_processor      : esm_pdw_sample_processor_debug_t;
  signal w_unpacked_pdw_encoder           : esm_pdw_encoder_debug_t;

  signal w_error                          : std_logic;

  attribute MARK_DEBUG                                : string;
  attribute DONT_TOUCH                                : string;
  attribute MARK_DEBUG of w_fifo_rd_en                : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_rd_en                : signal is "TRUE";
  attribute MARK_DEBUG of w_unpacked_sample_processor : signal is "TRUE";
  attribute DONT_TOUCH of w_unpacked_sample_processor : signal is "TRUE";
  attribute MARK_DEBUG of w_unpacked_pdw_encoder      : signal is "TRUE";
  attribute DONT_TOUCH of w_unpacked_pdw_encoder      : signal is "TRUE";

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_debug_sample_processor  <= Debug_sample_processor;
      r_debug_pdw_encoder       <= Debug_pdw_encoder;
    end if;
  end process;

  w_debug_sample_processor_packed <= pack(r_debug_sample_processor);
  w_debug_pdw_encoder_packed      <= pack(r_debug_pdw_encoder);

  w_error <= r_debug_pdw_encoder.w_pdw_fifo_overflow      or  r_debug_pdw_encoder.w_pdw_fifo_underflow      or
             r_debug_pdw_encoder.w_sample_buffer_busy     or  r_debug_pdw_encoder.w_sample_buffer_underflow or
             r_debug_pdw_encoder.w_sample_buffer_overflow or  r_debug_pdw_encoder.w_reporter_timeout        or
             r_debug_pdw_encoder.w_reporter_overflow;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_wr_en <= r_debug_sample_processor.w_pending_fifo_wr_en or r_debug_sample_processor.r_fifo_wr_en or
                      (r_debug_sample_processor.r2_input_ctrl_valid and to_stdlogic(r_debug_sample_processor.r2_context_state /= "00")) or
                      r_debug_pdw_encoder.w_pdw_valid       or r_debug_pdw_encoder.w_pdw_ready or
                      r_debug_pdw_encoder.w_frame_req_read  or r_debug_pdw_encoder.w_frame_req_drop or
                      r_debug_pdw_encoder.w_frame_ack_valid or r_debug_pdw_encoder.w_dwell_done or
                      r_debug_pdw_encoder.w_report_ack      or w_error;

      r_fifo_wr_data <= w_debug_pdw_encoder_packed & w_debug_sample_processor_packed;
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

  (w_fifo_debug_pdw_encoder, w_fifo_debug_sample_processor) <= w_fifo_rd_data;

  w_unpacked_sample_processor <= unpack(w_fifo_debug_sample_processor);
  w_unpacked_pdw_encoder      <= unpack(w_fifo_debug_pdw_encoder);

end architecture rtl;
