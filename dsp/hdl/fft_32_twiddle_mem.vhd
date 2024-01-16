library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_32_twiddle_mem is
generic (
  STAGE_INDEX : natural;
  DATA_WIDTH  : natural;
  LATENCY     : natural
);
port (
  Clk                 : in  std_logic;

  Read_index          : in  unsigned(4 downto 0);
  Read_data_c         : out signed(DATA_WIDTH - 1 downto 0);
  Read_data_c_plus_d  : out signed(DATA_WIDTH downto 0);
  Read_data_d_minus_c : out signed(DATA_WIDTH downto 0)
);
end entity fft_32_twiddle_mem;

architecture rtl of fft_32_twiddle_mem is

  constant NUM_CYCLES           : natural := 32;
  constant INIT_WIDTH_C         : natural := 23;
  constant INIT_WIDTH_C_PLUS_D  : natural := 24;
  constant INIT_WIDTH_D_MINUS_C : natural := 24;

  function initialize_w_c return signed_array_t is
    variable r : integer_array_t(0 to NUM_CYCLES-1);
  begin
    if (STAGE_INDEX = 8) then
      r := (4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821);
    elsif (STAGE_INDEX = 16) then
      r := (4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032, 4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032);
    elsif (STAGE_INDEX = 32) then
      r := (4194303, 4113712, 3875032, 3487436, 2965821, 2330230, 1605091, 818268, 0, -818268, -1605091, -2330230, -2965821, -3487436, -3875032, -4113712, -4194304, -4113712, -3875032, -3487436, -2965821, -2330230, -1605091, -818268, 0, 818268, 1605091, 2330230, 2965821, 3487436, 3875032, 4113712);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    return int_to_signed_array(r, INIT_WIDTH_C, DATA_WIDTH);
  end function;

  function initialize_w_c_plus_d return signed_array_t is
    variable r : integer_array_t(0 to NUM_CYCLES-1);
    variable s : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH downto 0);
  begin
    if (STAGE_INDEX = 8) then
      r := (4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642);
    elsif (STAGE_INDEX = 16) then
      r := (4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122);
    elsif (STAGE_INDEX = 32) then
      r := (4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444, -4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    return int_to_signed_array(r, INIT_WIDTH_C_PLUS_D, DATA_WIDTH + 1);
  end function;

  function initialize_w_d_minus_c return signed_array_t is
    variable r : integer_array_t(0 to NUM_CYCLES-1);
    variable s : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH downto 0);
  begin
    if (STAGE_INDEX = 8) then
      r := (-4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0);
    elsif (STAGE_INDEX = 16) then
      r := (-4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941);
    elsif (STAGE_INDEX = 32) then
      r := (-4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980, 4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    return int_to_signed_array(r, INIT_WIDTH_D_MINUS_C, DATA_WIDTH + 1);
  end function;

  constant W_C                  : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH - 1 downto 0) := initialize_w_c;
  constant W_C_PLUS_D           : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH     downto 0) := initialize_w_c_plus_d;
  constant W_D_MINUS_C          : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH     downto 0) := initialize_w_d_minus_c;

  signal r_read_data_c          : signed(DATA_WIDTH - 1 downto 0);
  signal r_read_data_c_plus_d   : signed(DATA_WIDTH downto 0);
  signal r_read_data_d_minus_c  : signed(DATA_WIDTH downto 0);

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32))
    report "Invalid stage index"
    severity failure;

  assert ((LATENCY = 0) or (LATENCY = 1) or (LATENCY = 2))
    report "Invalid latency"
    severity failure;

  assert (DATA_WIDTH <= INIT_WIDTH_C)
    report "Unsupported data width"
    severity failure;

  g_output : if (LATENCY = 0) generate

    Read_data_c         <= W_C(to_integer(Read_index));
    Read_data_c_plus_d  <= W_C_PLUS_D(to_integer(Read_index));
    Read_data_d_minus_c <= W_D_MINUS_C(to_integer(Read_index));

  elsif (LATENCY = 1) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        Read_data_c         <= W_C(to_integer(Read_index));
        Read_data_c_plus_d  <= W_C_PLUS_D(to_integer(Read_index));
        Read_data_d_minus_c <= W_D_MINUS_C(to_integer(Read_index));
      end if;
    end process;

  elsif (LATENCY = 2) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        r_read_data_c         <= W_C(to_integer(Read_index));
        r_read_data_c_plus_d  <= W_C_PLUS_D(to_integer(Read_index));
        r_read_data_d_minus_c <= W_D_MINUS_C(to_integer(Read_index));
      end if;
    end process;

    process(Clk)
    begin
      if rising_edge(Clk) then
        Read_data_c         <= r_read_data_c;
        Read_data_c_plus_d  <= r_read_data_c_plus_d;
        Read_data_d_minus_c <= r_read_data_d_minus_c;
      end if;
    end process;

  end generate;

end architecture rtl;
