library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library mem_lib;

entity ecm_config is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk_x4        : in  std_logic;

  S_axis_clk    : in  std_logic;
  S_axis_resetn : in  std_logic;
  S_axis_ready  : out std_logic;
  S_axis_valid  : in  std_logic;
  S_axis_data   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last   : in  std_logic;

  Rst_out       : out std_logic;
  Enable_status : out std_logic;
  Enable_chan   : out std_logic;
  Enable_synth  : out std_logic;

  Module_config : out ecm_config_data_t
);
end entity ecm_config;

architecture rtl of ecm_config is

  constant CDC_STAGES : natural := 3;

  type state_t is
  (
    S_WORD_0,
    S_WORD_1,
    S_WORD_2,
    S_WORD_3,
    S_DROP,
    S_ACTIVE_CONFIG_CONTROL,
    S_ACTIVE_CONFIG_MODULE,
    S_PADDING
  );

  signal r_axis_valid           : std_logic;
  signal r_axis_last            : std_logic;
  signal r_axis_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal s_state                : state_t;

  signal w_module_id            : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0);
  signal w_message_type         : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  signal w_address              : unsigned(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  signal r_module_id            : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0);
  signal r_message_type         : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  signal r_address              : unsigned(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  signal r_first                : std_logic;

  signal r_module_config        : ecm_config_data_t;
  signal w_mod_config_valid     : std_logic;
  signal w_mod_config_data      : std_logic_vector(ECM_CONFIG_DATA_WIDTH - 1 downto 0);
  signal w_mod_config_empty     : std_logic;
  signal w_mod_config_overflow  : std_logic;

  signal r_rst_out              : std_logic;
  signal r_enable_status        : std_logic;
  signal r_enable_chan          : std_logic;
  signal r_enable_synth         : std_logic;

  signal r_module_config_x4     : ecm_config_data_t; --from cdc fifo
  signal r_rst_out_x4           : std_logic_vector(CDC_STAGES - 1 downto 0);
  signal r_enable_chan_x4       : std_logic_vector(CDC_STAGES - 1 downto 0);
  signal r_enable_synth_x4      : std_logic_vector(CDC_STAGES - 1 downto 0);
  signal r_enable_status_x4     : std_logic_vector(CDC_STAGES - 1 downto 0);

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of r_rst_out_x4         : signal is "TRUE";
  attribute ASYNC_REG of r_enable_chan_x4     : signal is "TRUE";
  attribute ASYNC_REG of r_enable_synth_x4    : signal is "TRUE";
  attribute ASYNC_REG of r_enable_status_x4   : signal is "TRUE";

begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI data width expected to be 32."
    severity failure;

  S_axis_ready <= '1';

  process(S_axis_clk)
  begin
    if rising_edge(S_axis_clk) then
      r_axis_valid  <= S_axis_valid;
      r_axis_last   <= S_axis_last;
      r_axis_data   <= S_axis_data;
    end if;
  end process;

  w_module_id     <= unsigned(r_axis_data(24 + ECM_MODULE_ID_WIDTH - 1 downto 24));
  w_message_type  <= unsigned(r_axis_data(16 + ECM_MESSAGE_TYPE_WIDTH - 1 downto 16));
  w_address       <= unsigned(r_axis_data(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0));

  process(S_axis_clk)
  begin
    if rising_edge(S_axis_clk) then
      if (S_axis_resetn = '0') then
        s_state <= S_WORD_0;
      else
        if (r_axis_valid = '1') then
          case s_state is
          when S_WORD_0 =>
            if (r_axis_data = ECM_CONTROL_MAGIC_NUM) then
              s_state <= S_WORD_1;
            else
              s_state <= S_DROP;
            end if;

          when S_WORD_1 =>
            s_state <= S_WORD_2;

          when S_WORD_2 =>
            s_state <= S_WORD_3;

          when S_WORD_3 =>
            if (r_module_id = ECM_MODULE_ID_CONTROL) then
              s_state <= S_ACTIVE_CONFIG_CONTROL;
            else
              s_state <= S_ACTIVE_CONFIG_MODULE;
            end if;

          when S_DROP =>
            s_state <= S_DROP;

          when S_ACTIVE_CONFIG_CONTROL =>
            s_state <= S_PADDING;

          when S_ACTIVE_CONFIG_MODULE =>
            s_state <= S_ACTIVE_CONFIG_MODULE;

          when S_PADDING =>
            s_state <= S_PADDING;

          end case;

          if (r_axis_last = '1') then
            s_state <= S_WORD_0;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(S_axis_clk)
  begin
    if rising_edge(S_axis_clk) then
      if (s_state = S_WORD_2) then
        r_module_id     <= w_module_id;
        r_message_type  <= w_message_type;
        r_address       <= w_address;
      end if;

      if (r_axis_valid = '1') then
        r_first <= to_stdlogic(s_state = S_WORD_3);
      end if;
    end if;
  end process;

  process(S_axis_clk)
  begin
    if rising_edge(S_axis_clk) then
      r_module_config.valid         <= r_axis_valid and to_stdlogic(s_state = S_ACTIVE_CONFIG_MODULE);
      r_module_config.first         <= r_first;
      r_module_config.last          <= r_axis_last;
      r_module_config.data          <= r_axis_data;
      r_module_config.module_id     <= r_module_id;
      r_module_config.message_type  <= r_message_type;
      r_module_config.address       <= r_address;
    end if;
  end process;

  i_mod_config_fifo : entity mem_lib.xpm_async_fifo
  generic map (
    FIFO_DEPTH  => 16,
    FIFO_WIDTH  => ECM_CONFIG_DATA_WIDTH
  )
  port map (
    Clk_wr        => S_axis_clk,
    Clk_rd        => Clk_x4,
    Rst_wr        => not(S_axis_resetn),

    Wr_en         => r_module_config.valid,
    Wr_data       => pack(r_module_config),
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_mod_config_valid,
    Rd_data       => w_mod_config_data,
    Empty         => w_mod_config_empty,

    Overflow      => w_mod_config_overflow,
    Underflow     => open
  );

  assert (w_mod_config_overflow /= '1')
    report "Mod config fifo overflow"
    severity failure;

  w_mod_config_valid <= not(w_mod_config_empty);

  process(Clk_x4)
  begin
    if rising_edge(Clk_x4) then
      r_module_config_x4       <= unpack(w_mod_config_data);
      r_module_config_x4.valid <= w_mod_config_valid;
      Module_config            <= r_module_config_x4;
    end if;
  end process;

  process(S_axis_clk)
  begin
    if rising_edge(S_axis_clk) then
      if (S_axis_resetn = '0') then
        r_rst_out       <= '0';
        r_enable_chan   <= '0';
        r_enable_synth  <= '0';
        r_enable_status <= '0';
      else
        if ((r_axis_valid = '1') and (s_state = S_ACTIVE_CONFIG_CONTROL) and (r_first = '1') and (r_message_type = ECM_CONTROL_MESSAGE_TYPE_ENABLE)) then
          r_rst_out       <= r_axis_data(24);
          r_enable_chan   <= r_axis_data(16);
          r_enable_synth  <= r_axis_data(8);
          r_enable_status <= r_axis_data(0);
        end if;
      end if;
    end if;
  end process;

  process(Clk_x4)
  begin
    if rising_edge(Clk_x4) then
      r_rst_out_x4        <= r_rst_out_x4(CDC_STAGES - 2 downto 0)        & r_rst_out;
      r_enable_chan_x4    <= r_enable_chan_x4(CDC_STAGES - 2 downto 0)    & r_enable_chan;
      r_enable_synth_x4   <= r_enable_synth_x4(CDC_STAGES - 2 downto 0)   & r_enable_synth;
      r_enable_status_x4  <= r_enable_status_x4(CDC_STAGES - 2 downto 0)  & r_enable_status;
    end if;
  end process;

  Rst_out       <= r_rst_out_x4(CDC_STAGES - 1);
  Enable_chan   <= r_enable_chan_x4(CDC_STAGES - 1);
  Enable_synth  <= r_enable_synth_x4(CDC_STAGES - 1);
  Enable_status <= r_enable_status_x4(CDC_STAGES - 1);

end architecture rtl;
