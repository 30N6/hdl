library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package dsp_pkg is

  constant FFT8_DATA_INDEX_WIDTH      : natural := clog2(8);
  constant FFT32_DATA_INDEX_WIDTH     : natural := clog2(32);
  constant FFT64_DATA_INDEX_WIDTH     : natural := clog2(64);
  constant FFT_TAG_WIDTH              : natural := 8;

  constant CHAN_POWER_WIDTH           : natural := 32;

  constant DDS_LFSR_REG_WIDTH         : natural := 10;
  constant DDS_LFSR_PHASE_ACCUM_WIDTH : natural := 16;
  constant DDS_SIN_PHASE_ACCUM_WIDTH  : natural := 16;
  constant DDS_SIN_STEP_PERIOD_WIDTH  : natural := 16;
  constant DDS_SIN_LOOKUP_INDEX_WIDTH : natural := 10;

  constant DDS_CONTROL_TYPE_WIDTH     : natural := 2;
  constant DDS_CONTROL_TYPE_NONE      : natural := 0;
  constant DDS_CONTROL_TYPE_LFSR      : natural := 1;
  constant DDS_CONTROL_TYPE_SIN_SWEEP : natural := 2;
  constant DDS_CONTROL_TYPE_SIN_STEP  : natural := 3;

  constant SYNTHESIZER_SHIFT_CODE_WIDTH     : natural := 2;
  constant SYNTHESIZER_SHIFT_MAP            : natural_array_t(2**SYNTHESIZER_SHIFT_CODE_WIDTH - 1 downto 0) := (5, 4, 3, 2);
  constant SYNTHESIZER_COUNT_TO_SHIFT_CODE  : natural_array_t(31 downto 0) := (11 => 2, 10 => 2, 9 => 2, 8 => 2, 7 => 2, 6 => 2, 5 => 2, 4 => 2,
                                                                               3 => 1, 2 => 1,
                                                                               1 => 0, 0 => 0,
                                                                               others => 3);
  constant SYNTHESIZER_CHANNEL_COUNT_WIDTH  : natural := clog2(16 + 1);

  type fft_control_t is record
    valid       : std_logic;
    last        : std_logic;
    reverse     : std_logic;
    data_index  : unsigned(5 downto 0);
    tag         : std_logic_vector(FFT_TAG_WIDTH - 1 downto 0);
  end record;

  type fft_control_array_t is array (natural range <>) of fft_control_t;

  type channelizer_control_t is record
    valid       : std_logic;
    last        : std_logic;
    data_index  : unsigned(5 downto 0);
  end record;

  type channelizer_control_array_t is array (natural range <>) of channelizer_control_t;

  type synthesizer_control_t is record
    valid                 : std_logic;
    last                  : std_logic;
    data_index            : unsigned(5 downto 0);
    transmit_active       : std_logic;
    active_channel_count  : unsigned(SYNTHESIZER_CHANNEL_COUNT_WIDTH - 1 downto 0);
  end record;

  type synthesizer_control_array_t is array (natural range <>) of synthesizer_control_t;


  type dds_control_setup_entry_t is record
    dds_sin_phase_inc_select  : std_logic;  -- 0=sweep, 1=step
    dds_output_select         : std_logic_vector(1 downto 0); -- 00=off, 01=lfsr, 10=sweep, 11=mixer
  end record;
  constant DDS_CONTROL_SETUP_ENTRY_PACKED_WIDTH : natural := 3;

  type dds_control_lfsr_entry_t is record
    lfsr_phase_inc                      : unsigned(DDS_LFSR_PHASE_ACCUM_WIDTH - 1 downto 0);
  end record;
  constant DDS_CONTROL_LFSR_ENTRY_PACKED_WIDTH : natural := 16;

  type dds_control_sin_sweep_entry_t is record
    sin_sweep_phase_inc_start           : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_sweep_phase_inc_stop            : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_sweep_phase_inc_step            : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
  end record;
  constant DDS_CONTROL_SIN_SWEEP_ENTRY_PACKED_WIDTH : natural := 48;

  type dds_control_sin_step_entry_t is record
    sin_step_phase_inc_min              : signed(DDS_SIN_PHASE_ACCUM_WIDTH - 1 downto 0);
    sin_step_phase_inc_rand_offset_mask : unsigned(DDS_SIN_PHASE_ACCUM_WIDTH - 2 downto 0);
    sin_step_period_minus_one           : unsigned(DDS_SIN_STEP_PERIOD_WIDTH - 1 downto 0);
  end record;
  constant DDS_CONTROL_SIN_STEP_ENTRY_PACKED_WIDTH : natural := 48;

  constant DDS_CONTROL_ENTRY_PACKED_WIDTH : natural := 48;

  type dds_control_t is record
    valid         : std_logic;
    channel_index : unsigned(5 downto 0);

    setup_data    : dds_control_setup_entry_t;

    control_type  : unsigned(DDS_CONTROL_TYPE_WIDTH - 1 downto 0);
    control_data  : std_logic_vector(DDS_CONTROL_ENTRY_PACKED_WIDTH - 1 downto 0);
  end record;

  function invert_sign(v : signed; saturate : boolean) return signed;
  function int_to_signed_array(int_array : integer_array_t; output_length : natural; input_width : natural; output_width : natural) return signed_array_t;

  function unpack(v : std_logic_vector(DDS_CONTROL_SETUP_ENTRY_PACKED_WIDTH - 1 downto 0)) return dds_control_setup_entry_t;
  function unpack(v : std_logic_vector) return dds_control_lfsr_entry_t;
  function unpack(v : std_logic_vector) return dds_control_sin_sweep_entry_t;
  function unpack(v : std_logic_vector) return dds_control_sin_step_entry_t;

  function lfsr_output(x : unsigned; poly : unsigned) return std_logic;
  function update_lfsr(x : unsigned; poly : unsigned) return unsigned;

end package dsp_pkg;

package body dsp_pkg is

  function invert_sign(v : signed; saturate : boolean) return signed is
    variable r      : signed(v'length - 1 downto 0);
    constant V_MAX  : signed(v'length - 1 downto 0) := ((v'length - 1) => '0', others => '1');
    constant V_MIN  : signed(v'length - 1 downto 0) := ((v'length - 1) => '1', others => '0');
  begin
    if (saturate and (v = V_MAX)) then
      r := V_MIN;
    else
      r := -v;
    end if;
    return r;
  end function;

  function int_to_signed_array(int_array : integer_array_t; output_length : natural; input_width : natural; output_width : natural) return signed_array_t is
    variable v_full_signed : signed(input_width - 1 downto 0);
    variable v_result : signed_array_t(0 to output_length - 1)(output_width - 1 downto 0);
  begin
    assert (output_width <= input_width)
      report "output_width expected to be less than or equal to the input_width."
      severity failure;

    for i in 0 to (output_length - 1) loop
      v_full_signed := to_signed(int_array(i), input_width);
      v_result(i)   := v_full_signed(input_width - 1 downto (input_width - output_width));
      --report "int_to_signed_array: i=" & integer'image(i) & " - " & integer'image(int_array(i)) & " " & to_hstring(v_full_signed) & " " & to_hstring(v_result(i));
    end loop;
    return v_result;
  end function;

  function unpack(v : std_logic_vector(DDS_CONTROL_SETUP_ENTRY_PACKED_WIDTH - 1 downto 0)) return dds_control_setup_entry_t is  --TODO: redo unpack functions - add vector dimensions
    variable r  : dds_control_setup_entry_t;
  begin
    r.dds_sin_phase_inc_select  := v(0);
    r.dds_output_select         := v(2 downto 1);
    return r;
  end function;

  function unpack(v : std_logic_vector) return dds_control_lfsr_entry_t is
    variable vm : std_logic_vector(v'length - 1 downto 0);
    variable r  : dds_control_lfsr_entry_t;
  begin
    assert (v'length = DDS_CONTROL_LFSR_ENTRY_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;
    vm := v;

    r.lfsr_phase_inc := unsigned(vm(15 downto 0));

    return r;
  end function;

  function unpack(v : std_logic_vector) return dds_control_sin_sweep_entry_t is
    variable vm : std_logic_vector(v'length - 1 downto 0);
    variable r  : dds_control_sin_sweep_entry_t;
  begin
    assert (v'length = DDS_CONTROL_SIN_SWEEP_ENTRY_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;
    vm := v;

    r.sin_sweep_phase_inc_start := signed(vm(15 downto 0));
    r.sin_sweep_phase_inc_stop  := signed(vm(31 downto 16));
    r.sin_sweep_phase_inc_step  := signed(vm(47 downto 32));

    return r;
  end function;

  function unpack(v : std_logic_vector) return dds_control_sin_step_entry_t is
    variable vm : std_logic_vector(v'length - 1 downto 0);
    variable r  : dds_control_sin_step_entry_t;
  begin
    assert (v'length = DDS_CONTROL_SIN_STEP_ENTRY_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;
    vm := v;

    r.sin_step_phase_inc_min              := signed(vm(15 downto 0));
    r.sin_step_phase_inc_rand_offset_mask := unsigned(vm(30 downto 16));
    r.sin_step_period_minus_one           := unsigned(vm(47 downto 32));

    return r;
  end function;

  function lfsr_output(x : unsigned; poly : unsigned) return std_logic is
    variable r : std_logic;
  begin
    r := '0';

    for i in 0 to (x'length - 1) loop
      if (poly(i) = '1') then
        r := r xor x(i);
      end if;
    end loop;

    return r;
  end function;

  function update_lfsr(x : unsigned; poly : unsigned) return unsigned is
    variable r : unsigned(x'length downto 0);
  begin

    r := x & lfsr_output(x, poly);
    return r(x'length - 1 downto 0);
  end function;



end package body dsp_pkg;
