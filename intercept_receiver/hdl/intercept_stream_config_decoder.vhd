library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_stream_config_decoder is
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Module_config         : in  intercept_config_data_t;

  Channel_config_valid  : out std_logic;
  Channel_config_index  : out unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  Channel_config_data   : out intercept_message_stream_encoder_channel_control_t;

  Stream_config_valid   : out std_logic;
  Stream_config_index   : out unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
  Stream_config_data    : out intercept_message_stream_encoder_stream_control_t
);
end entity intercept_stream_config_decoder;

architecture rtl of intercept_stream_config_decoder is

  constant PACKED_HEADER_WIDTH              : natural := maximum(INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH,
                                                                 INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH);
  constant NUM_HEADER_WORDS                 : natural := PACKED_HEADER_WIDTH / 32;
  constant NUM_HEADER_WORDS_CHANNEL_CONTROL : natural := INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH / 32;
  constant NUM_HEADER_WORDS_STREAM_CONTROL  : natural := INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH / 32;

  type state_t is
  (
    S_IDLE,
    S_HEADER
  );

  type message_type_t is
  (
    CHANNEL_CONTROL,
    STREAM_CONTROL
  );

  signal s_state                : state_t;

  signal r_module_config        : intercept_config_data_t;
  signal w_module_id_match      : std_logic;
  signal w_message_type_match   : std_logic;

  signal r_packed_data          : std_logic_vector(PACKED_HEADER_WIDTH - 1 downto 0);
  signal r_header_index         : unsigned(clog2(NUM_HEADER_WORDS) - 1 downto 0);
  signal r_header_active        : std_logic;

  signal w_header_done          : std_logic;
  signal r_header_done          : std_logic;

  signal r_message_type         : message_type_t;
  signal r_header_word_length   : unsigned(clog2(NUM_HEADER_WORDS) - 1 downto 0);

  signal r_address              : unsigned(INTERCEPT_CONFIG_ADDRESS_WIDTH - 1 downto 0);

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

  w_module_id_match     <= to_stdlogic(r_module_config.module_id = INTERCEPT_MODULE_ID_STREAM_ENCODER);
  w_message_type_match  <= to_stdlogic(r_module_config.message_type = INTERCEPT_CONTROL_MESSAGE_TYPE_CHANNEL_CONFIG) or
                           to_stdlogic(r_module_config.message_type = INTERCEPT_CONTROL_MESSAGE_TYPE_STREAM_CONFIG);

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
              s_state <= S_IDLE;
            else
              s_state <= S_HEADER;
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
        r_address <= r_module_config.address;

        if (r_module_config.message_type = INTERCEPT_CONTROL_MESSAGE_TYPE_CHANNEL_CONFIG) then
          r_message_type        <= CHANNEL_CONTROL;
          r_header_word_length  <= to_unsigned(NUM_HEADER_WORDS_CHANNEL_CONTROL, r_header_word_length'length);
        else
          r_message_type        <= STREAM_CONTROL;
          r_header_word_length  <= to_unsigned(NUM_HEADER_WORDS_STREAM_CONTROL, r_header_word_length'length);
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

  process(Clk)
  begin
    if rising_edge(Clk) then
      Channel_config_valid  <= r_header_done and to_stdlogic(r_message_type = CHANNEL_CONTROL);
      Channel_config_index  <= r_address(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
      Channel_config_data   <= unpack_aligned(r_packed_data(INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH - 1 downto 0));

      Stream_config_valid   <= r_header_done and to_stdlogic(r_message_type = STREAM_CONTROL);
      Stream_config_index   <= r_address(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
      Stream_config_data    <= unpack_aligned(r_packed_data(INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH - 1 downto 0));
    end if;
  end process;

end architecture rtl;
