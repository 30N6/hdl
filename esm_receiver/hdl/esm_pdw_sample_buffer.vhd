library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_pdw_sample_buffer is
generic (
  DATA_WIDTH        : natural;
  SAMPLES_PER_FRAME : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Buffer_full         : out std_logic;
  Buffer_next_index   : out unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  Buffer_next_start   : in  std_logic;

  Input_valid         : in  std_logic;
  Input_frame_index   : in  unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  Input_sample_index  : in  unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
  Input_data          : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_frame_req    : in  esm_pdw_sample_buffer_req_t;
  Output_frame_ack    : out esm_pdw_sample_buffer_ack_t;
  Output_sample_data  : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Error_underflow     : out std_logic;
  Error_overflow      : out std_logic
);
end entity esm_pdw_sample_buffer;

architecture rtl of esm_pdw_sample_buffer is

  constant MEM_ADDR_WIDTH         : natural := ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH + ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH;
  constant MEM_DATA_WIDTH         : natural := 2*DATA_WIDTH;

  signal m_buffer                 : std_logic_vector_array_t(2**MEM_ADDR_WIDTH - 1 downto 0)(MEM_DATA_WIDTH - 1 downto 0);

  signal w_wr_addr                : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_wr_data                : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
  signal w_rd_addr                : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal r_rd_data                : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);

  signal r_buffer_pending         : std_logic_vector(2**ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  signal w_buffer_full            : std_logic;
  signal w_buffer_next_index      : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);

  signal r_output_valid           : std_logic;
  signal r_output_frame_index     : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  signal r_output_sample_index    : unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
  signal r_output_sample_last     : std_logic;

  signal r_output_valid_d         : std_logic;
  signal r_output_sample_index_d  : unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
  signal r_output_sample_last_d   : std_logic;

begin

  w_wr_addr <= Input_frame_index & Input_sample_index;
  w_wr_data <= std_logic_vector(Input_data(1)) & std_logic_vector(Input_data(0));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        m_buffer(to_integer(w_wr_addr)) <= w_wr_data;
      end if;
    end if;
  end process;

  process(all)
    variable v_next_index : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  begin
    v_next_index := (others => '0');
    for i in 0 to (2**ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1) loop
      if (r_buffer_pending(i) = '0') then
        v_next_index := to_unsigned(i, ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH);
        exit;
      end if;
    end loop;
    w_buffer_next_index <= v_next_index;
  end process;

  w_buffer_full <= and_reduce(r_buffer_pending);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_buffer_pending <= (others => '0');
      else
        if (Buffer_next_start = '1') then
          r_buffer_pending(to_integer(w_buffer_next_index)) <= '1';
        end if;
        if ((r_output_valid = '1') and (r_output_sample_last = '1')) then
          r_buffer_pending(to_integer(r_output_frame_index)) <= '0';
        end if;
      end if;
    end if;
  end process;

  Buffer_full       <= w_buffer_full;
  Buffer_next_index <= w_buffer_next_index;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_output_valid        <= '0';
        r_output_sample_last  <= '-';
        r_output_frame_index  <= (others => '-');
        r_output_sample_index <= (others => '-');
      else
        if (Output_frame_req.frame_read = '1') then
          r_output_valid        <= '1';
          r_output_frame_index  <= Output_frame_req.frame_index;
          r_output_sample_index <= (others => '0');
          r_output_sample_last  <= '0';
        elsif (r_output_valid = '1') then
          if (r_output_sample_index = (SAMPLES_PER_FRAME - 1)) then
            r_output_valid        <= '0';
            r_output_sample_last  <= '-';
            r_output_frame_index  <= (others => '-');
            r_output_sample_index <= (others => '-');
          else
            r_output_sample_index <= r_output_sample_index + 1;
            r_output_sample_last  <= to_stdlogic(r_output_sample_index = (SAMPLES_PER_FRAME - 2));
          end if;
        end if;
      end if;
    end if;
  end process;

  w_rd_addr <= r_output_frame_index & r_output_sample_index;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rd_data               <= m_buffer(to_integer(w_rd_addr));
      r_output_valid_d        <= r_output_valid;
      r_output_sample_index_d <= r_output_sample_index;
      r_output_sample_last_d  <= r_output_sample_last;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_sample_data(1)           <= signed(r_rd_data(MEM_DATA_WIDTH - 1 downto DATA_WIDTH));
      Output_sample_data(0)           <= signed(r_rd_data(DATA_WIDTH - 1 downto 0));
      Output_frame_ack.sample_index   <= r_output_sample_index_d;
      Output_frame_ack.sample_last    <= r_output_sample_last_d;
      Output_frame_ack.sample_valid   <= r_output_valid_d;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_underflow <= Output_frame_req.frame_read and not(r_buffer_pending(to_integer(Output_frame_req.frame_index)));
      Error_overflow  <= Buffer_next_start and w_buffer_full;
    end if;
  end process;

end architecture rtl;
