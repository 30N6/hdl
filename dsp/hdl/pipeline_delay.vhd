library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity pipeline_delay is
generic (
  DATA_WIDTH    : natural;
  LATENCY       : natural
);
port (
  Clk           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_data    : in  unsigned(DATA_WIDTH - 1 downto 0);

  Output_valid  : out std_logic;
  Output_data   : out unsigned(DATA_WIDTH - 1 downto 0)
);
end entity pipeline_delay;

architecture rtl of pipeline_delay is

  type data_array_t is array (natural range <>) of unsigned(DATA_WIDTH - 1 downto 0);

  signal r_pipe_data      : data_array_t(LATENCY - 1 downto 0);
  signal r_output_valid   : std_logic;

  --TODO: SRL attribute?

begin

  assert (LATENCY <= 128)
    report "LATENCY expected to be 128 or less. Otherwise, the pipeline may not efficiently fit into SRLs."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_valid <= Input_valid;

      if (Input_valid = '1') then
        r_pipe_data <= r_pipe_data(LATENCY - 2 downto 0) & Input_data;
      end if;
    end if;
  end process;

  Output_valid  <= r_output_valid;
  Output_data   <= r_pipe_data(LATENCY - 1);

end architecture rtl;
