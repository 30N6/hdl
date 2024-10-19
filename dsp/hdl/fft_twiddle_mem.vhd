library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_twiddle_mem is
generic (
  NUM_CYCLES        : natural;
  CYCLE_INDEX_WIDTH : natural;
  STAGE_INDEX       : natural;
  DATA_WIDTH        : natural;
  LATENCY           : natural
);
port (
  Clk                 : in  std_logic;

  Read_index          : in  unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);
  Read_data_c         : out signed(DATA_WIDTH - 1 downto 0);
  Read_data_c_plus_d  : out signed(DATA_WIDTH downto 0);
  Read_data_d_minus_c : out signed(DATA_WIDTH downto 0)
);
end entity fft_twiddle_mem;

architecture rtl of fft_twiddle_mem is

  constant MAX_CYCLES           : natural := 64;

  constant INIT_WIDTH_C         : natural := 23;
  constant INIT_WIDTH_C_PLUS_D  : natural := 24;
  constant INIT_WIDTH_D_MINUS_C : natural := 24;

  --TODO: cleanup - remove int to signed conversions
  function initialize_w_c return signed_array_t is
    variable r : integer_array_t(0 to MAX_CYCLES-1);
    variable s : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH - 1 downto 0);
  begin
    if (STAGE_INDEX = 8) then
      r := (4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821, 4194303, 2965821, 0, -2965821, -4194304, -2965821, 0, 2965821);
    elsif (STAGE_INDEX = 16) then
      r := (4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032, 4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032, 4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032, 4194303, 3875032, 2965821, 1605091, 0, -1605091, -2965821, -3875032, -4194304, -3875032, -2965821, -1605091, 0, 1605091, 2965821, 3875032);
    elsif (STAGE_INDEX = 32) then
      r := (4194303, 4113712, 3875032, 3487436, 2965821, 2330230, 1605091, 818268, 0, -818268, -1605091, -2330230, -2965821, -3487436, -3875032, -4113712, -4194304, -4113712, -3875032, -3487436, -2965821, -2330230, -1605091, -818268, 0, 818268, 1605091, 2330230, 2965821, 3487436, 3875032, 4113712, 4194303, 4113712, 3875032, 3487436, 2965821, 2330230, 1605091, 818268, 0, -818268, -1605091, -2330230, -2965821, -3487436, -3875032, -4113712, -4194304, -4113712, -3875032, -3487436, -2965821, -2330230, -1605091, -818268, 0, 818268, 1605091, 2330230, 2965821, 3487436, 3875032, 4113712);
    elsif (STAGE_INDEX = 64) then
      r := (4194303, 4174107, 4113712, 4013699, 3875032, 3699046, 3487436, 3242241, 2965821, 2660838, 2330230, 1977181, 1605091, 1217542, 818268, 411114, 0, -411114, -818268, -1217542, -1605091, -1977181, -2330230, -2660838, -2965821, -3242241, -3487436, -3699046, -3875032, -4013699, -4113712, -4174107, -4194304, -4174107, -4113712, -4013699, -3875032, -3699046, -3487436, -3242241, -2965821, -2660838, -2330230, -1977181, -1605091, -1217542, -818268, -411114, 0, 411114, 818268, 1217542, 1605091, 1977181, 2330230, 2660838, 2965821, 3242241, 3487436, 3699046, 3875032, 4013699, 4113712, 4174107);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    --report "initialize_w_c: stage=" & integer'image(STAGE_INDEX) & "  r(0,1,2)= " & integer'image(r(0)) & " " & integer'image(r(1)) & " " & integer'image(r(2));
    s := int_to_signed_array(r, NUM_CYCLES, INIT_WIDTH_C, DATA_WIDTH);
    --report "initialize_w_c: s(0,1,2)= " & to_hstring(s(0)) & " " & to_hstring(s(1)) & " " & to_hstring(s(2));
    return s;
  end function;

  function initialize_w_c_plus_d return signed_array_t is
    variable r : integer_array_t(0 to MAX_CYCLES-1);
    variable s : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH downto 0);
  begin
    if (STAGE_INDEX = 8) then
      r := (4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642);
    elsif (STAGE_INDEX = 16) then
      r := (4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122);
    elsif (STAGE_INDEX = 32) then
      r := (4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444, -4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980, 4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444, -4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980);
    elsif (STAGE_INDEX = 64) then
      r := (4194304, 3762994, 3295444, 2796156, 2269941, 1721865, 1157206, 581403, 0, -581403, -1157206, -1721865, -2269941, -2796156, -3295444, -3762994, -4194304, -4585221, -4931980, -5231241, -5480122, -5676227, -5817667, -5903079, -5931642, -5903079, -5817667, -5676227, -5480122, -5231241, -4931980, -4585221, -4194304, -3762994, -3295444, -2796156, -2269941, -1721865, -1157206, -581403, 0, 581403, 1157206, 1721865, 2269941, 2796156, 3295444, 3762994, 4194304, 4585221, 4931980, 5231241, 5480122, 5676227, 5817667, 5903079, 5931642, 5903079, 5817667, 5676227, 5480122, 5231241, 4931980, 4585221);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    return int_to_signed_array(r, NUM_CYCLES, INIT_WIDTH_C_PLUS_D, DATA_WIDTH + 1);
  end function;

  function initialize_w_d_minus_c return signed_array_t is
    variable r : integer_array_t(0 to MAX_CYCLES-1);
    variable s : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH downto 0);
  begin
    if (STAGE_INDEX = 8) then
      r := (-4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0, -4194304, -5931642, -4194304, 0, 4194304, 5931642, 4194304, 0);
    elsif (STAGE_INDEX = 16) then
      r := (-4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941, -4194304, -5480122, -5931642, -5480122, -4194304, -2269941, 0, 2269941, 4194304, 5480122, 5931642, 5480122, 4194304, 2269941, 0, -2269941);
    elsif (STAGE_INDEX = 32) then
      r := (-4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980, 4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444, -4194304, -4931980, -5480122, -5817667, -5931642, -5817667, -5480122, -4931980, -4194304, -3295444, -2269941, -1157206, 0, 1157206, 2269941, 3295444, 4194304, 4931980, 5480122, 5817667, 5931642, 5817667, 5480122, 4931980, 4194304, 3295444, 2269941, 1157206, 0, -1157206, -2269941, -3295444);
    elsif (STAGE_INDEX = 64) then
      r := (-4194304, -4585221, -4931980, -5231241, -5480122, -5676227, -5817667, -5903079, -5931642, -5903079, -5817667, -5676227, -5480122, -5231241, -4931980, -4585221, -4194304, -3762994, -3295444, -2796156, -2269941, -1721865, -1157206, -581403, 0, 581403, 1157206, 1721865, 2269941, 2796156, 3295444, 3762994, 4194304, 4585221, 4931980, 5231241, 5480122, 5676227, 5817667, 5903079, 5931642, 5903079, 5817667, 5676227, 5480122, 5231241, 4931980, 4585221, 4194304, 3762994, 3295444, 2796156, 2269941, 1721865, 1157206, 581403, 0, -581403, -1157206, -1721865, -2269941, -2796156, -3295444, -3762994);
    else
      report "Invalid stage index."
      severity failure;
    end if;
    return int_to_signed_array(r, NUM_CYCLES, INIT_WIDTH_D_MINUS_C, DATA_WIDTH + 1);
  end function;

  constant W_C                  : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH - 1 downto 0) := initialize_w_c;
  constant W_C_PLUS_D           : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH     downto 0) := initialize_w_c_plus_d;
  constant W_D_MINUS_C          : signed_array_t(0 to NUM_CYCLES-1)(DATA_WIDTH     downto 0) := initialize_w_d_minus_c;

  signal w0_read_data_c         : signed(DATA_WIDTH - 1 downto 0);
  signal w0_read_data_c_plus_d  : signed(DATA_WIDTH downto 0);
  signal w0_read_data_d_minus_c : signed(DATA_WIDTH downto 0);
  signal r1_read_data_c         : signed(DATA_WIDTH - 1 downto 0);
  signal r1_read_data_c_plus_d  : signed(DATA_WIDTH downto 0);
  signal r1_read_data_d_minus_c : signed(DATA_WIDTH downto 0);
  signal r2_read_data_c         : signed(DATA_WIDTH - 1 downto 0);
  signal r2_read_data_c_plus_d  : signed(DATA_WIDTH downto 0);
  signal r2_read_data_d_minus_c : signed(DATA_WIDTH downto 0);

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32) or (STAGE_INDEX = 64))
    report "Invalid stage index"
    severity failure;

  assert (LATENCY <= 3)
    report "LATENCY must be 3 or less."
    severity failure;

  assert (DATA_WIDTH <= INIT_WIDTH_C)
    report "Unsupported data width"
    severity failure;

  w0_read_data_c         <= W_C(to_integer(Read_index));
  w0_read_data_c_plus_d  <= W_C_PLUS_D(to_integer(Read_index));
  w0_read_data_d_minus_c <= W_D_MINUS_C(to_integer(Read_index));

  g_output : if (LATENCY = 0) generate

    Read_data_c         <= w0_read_data_c;
    Read_data_c_plus_d  <= w0_read_data_c_plus_d;
    Read_data_d_minus_c <= w0_read_data_d_minus_c;

  elsif (LATENCY = 1) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        Read_data_c         <= w0_read_data_c;
        Read_data_c_plus_d  <= w0_read_data_c_plus_d;
        Read_data_d_minus_c <= w0_read_data_d_minus_c;
      end if;
    end process;

  elsif (LATENCY = 2) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        r1_read_data_c         <= w0_read_data_c;
        r1_read_data_c_plus_d  <= w0_read_data_c_plus_d;
        r1_read_data_d_minus_c <= w0_read_data_d_minus_c;
      end if;
    end process;

    process(Clk)
    begin
      if rising_edge(Clk) then
        Read_data_c         <= r1_read_data_c;
        Read_data_c_plus_d  <= r1_read_data_c_plus_d;
        Read_data_d_minus_c <= r1_read_data_d_minus_c;
      end if;
    end process;

  elsif (LATENCY = 3) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        r1_read_data_c         <= w0_read_data_c;
        r1_read_data_c_plus_d  <= w0_read_data_c_plus_d;
        r1_read_data_d_minus_c <= w0_read_data_d_minus_c;

        r2_read_data_c         <= r1_read_data_c;
        r2_read_data_c_plus_d  <= r1_read_data_c_plus_d;
        r2_read_data_d_minus_c <= r1_read_data_d_minus_c;
      end if;
    end process;

    process(Clk)
    begin
      if rising_edge(Clk) then
        Read_data_c         <= r2_read_data_c;
        Read_data_c_plus_d  <= r2_read_data_c_plus_d;
        Read_data_d_minus_c <= r2_read_data_d_minus_c;
      end if;
    end process;

  end generate;

end architecture rtl;
