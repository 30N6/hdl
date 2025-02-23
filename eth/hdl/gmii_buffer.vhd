library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library mem_lib;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity gmii_buffer is
generic (
  DATA_DEPTH    : natural;
  FRAME_DEPTH   : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Input_data      : in  std_logic_vector(7 downto 0);
  Input_valid     : in  std_logic;
  Input_error     : in  std_logic;
  Input_accepted  : out std_logic;
  Input_dropped   : out std_logic;

  Output_data     : out std_logic_vector(7 downto 0);
  Output_valid    : out std_logic;
  Output_last     : out std_logic;
  Output_ready    : in  std_logic

);
begin
  -- PSL default clock is rising_edge(Clk);
  -- PSL output_accepted_or_dropped : assert always (rose(Input_valid)) -> eventually! ((Input_accepted = '1') or (Input_dropped = '1'));
end entity gmii_buffer;

architecture rtl of gmii_buffer is

  type state_t is (S_IDLE, S_ACTIVE, S_ERROR, S_STORE, S_DROP);

  constant BUFFER_ADDR_WIDTH            : natural := clog2(DATA_DEPTH);
  constant BUFFER_DATA_WIDTH            : natural := 8;
  constant BUFFER_LATENCY               : natural := 2;

  constant FRAME_FIFO_WIDTH             : natural := 2*BUFFER_ADDR_WIDTH;
  constant FRAME_FIFO_ALMOST_FULL_LEVEL : natural := FRAME_DEPTH - 5;

  signal r0_input_data                  : std_logic_vector(7 downto 0);
  signal r0_input_valid                 : std_logic;
  signal r0_input_error                 : std_logic;

  signal r1_input_data                  : std_logic_vector(7 downto 0);
  signal r1_input_valid                 : std_logic;
  signal r1_input_error                 : std_logic;
  signal w1_input_last                  : std_logic;

  signal s_state                        : state_t;

  signal w_buffer_full                  : std_logic;

  signal w_buffer_write_valid           : std_logic;
  signal r_write_index_prev             : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal r_write_index_next             : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal r_write_index_first            : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal r_write_active                 : std_logic;
  signal r_write_error                  : std_logic;

  signal r_buffer_wr_addr               : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal r_buffer_wr_data               : std_logic_vector(7 downto 0);
  signal r_buffer_wr_en                 : std_logic;
  signal w_buffer_rd_data               : std_logic_vector(7 downto 0);

  signal r_frame_fifo_wr_data           : std_logic_vector(FRAME_FIFO_WIDTH - 1 downto 0);
  signal r_frame_fifo_wr_en             : std_logic;
  signal w_frame_fifo_almost_full       : std_logic;
  signal w_frame_fifo_rd_data           : std_logic_vector(FRAME_FIFO_WIDTH - 1 downto 0);
  signal w_frame_fifo_rd_en             : std_logic;
  signal w_frame_fifo_empty             : std_logic;

  signal r_read_active                  : std_logic;
  signal r_read_done                    : std_logic;
  signal r_read_index_curr              : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal r_read_index_last              : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_read_index_first             : unsigned(BUFFER_ADDR_WIDTH - 1 downto 0);

  signal r_read_valid                   : std_logic_vector(BUFFER_LATENCY - 1 downto 0);
  signal r_read_last                    : std_logic_vector(BUFFER_LATENCY - 1 downto 0);

  signal w_output_ready                 : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_data   <= Input_data;
      r0_input_valid  <= Input_valid;
      r0_input_error  <= Input_error;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_data   <= r0_input_data;
      r1_input_valid  <= r0_input_valid;
      r1_input_error  <= r0_input_error;
    end if;
  end process;

  w1_input_last <= r1_input_valid and not(r0_input_valid);
  w_buffer_full <= not(w_frame_fifo_empty) and to_stdlogic((r_write_index_next + 1) = w_read_index_first);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if (r1_input_valid = '1') then
            if ((r1_input_error = '1') or (w_buffer_full = '1')) then
              if (w1_input_last = '1') then
                s_state <= S_DROP;
              else
                s_state <= S_ERROR;
              end if;
            else
              s_state <= S_ACTIVE;
            end if;
          else
            s_state <= S_IDLE;
          end if;

        when S_ACTIVE =>
          if (r1_input_valid = '1') then
            if ((r1_input_error = '1') or (w_buffer_full = '1')) then
              if (w1_input_last = '1') then
                s_state <= S_DROP;
              else
                s_state <= S_ERROR;
              end if;
            else
              if (w1_input_last = '1') then
                if (w_frame_fifo_almost_full = '1') then
                  s_state <= S_DROP;
                else
                  s_state <= S_STORE;
                end if;
              else
                s_state <= S_ACTIVE;
              end if;
            end if;
          else
            s_state <= S_IDLE;
          end if;

        when S_ERROR =>
          if (r1_input_valid = '1') then
            if (w1_input_last = '1') then
              s_state <= S_DROP;
            else
              s_state <= S_ERROR;
            end if;
          else
            s_state <= S_IDLE;
          end if;

        when S_STORE =>
          s_state <= S_IDLE;

        when S_DROP =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  w_buffer_write_valid <= r1_input_valid and to_stdlogic((s_state = S_IDLE) or (s_state = S_ACTIVE));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_write_index_next <= (others => '0');
      else
        if (w_buffer_write_valid = '1') then
          r_write_index_next <= r_write_index_next + 1;
        elsif (s_state = S_DROP) then
          r_write_index_next <= r_write_index_first;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_write_index_first <= r_write_index_next;
      end if;

      r_write_index_prev <= r_write_index_next;
    end if;
  end process;

  Input_accepted  <= to_stdlogic(s_state = S_STORE);
  Input_dropped   <= to_stdlogic(s_state = S_DROP);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_buffer_wr_addr      <= r_write_index_next;
      r_buffer_wr_data      <= r1_input_data;
      r_buffer_wr_en        <= w_buffer_write_valid;

      r_frame_fifo_wr_data  <= std_logic_vector(r_write_index_prev) & std_logic_vector(r_write_index_first);
      r_frame_fifo_wr_en    <= to_stdlogic(s_state = S_STORE);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_active     <= '0';
        r_read_done       <= '-';
        r_read_index_curr <= (others => '-');
        r_read_index_last <= (others => '-');
      else
        if (r_read_active = '0') then
          if ((w_output_ready = '1') and (w_frame_fifo_empty = '0')) then
            r_read_active <= '1';
            r_read_index_curr <= unsigned(w_frame_fifo_rd_data(BUFFER_ADDR_WIDTH - 1 downto 0));
            r_read_index_last <= unsigned(w_frame_fifo_rd_data(2*BUFFER_ADDR_WIDTH - 1 downto BUFFER_ADDR_WIDTH));
            r_read_done       <= to_stdlogic(w_frame_fifo_rd_data(BUFFER_ADDR_WIDTH - 1 downto 0) = w_frame_fifo_rd_data(2*BUFFER_ADDR_WIDTH - 1 downto BUFFER_ADDR_WIDTH));
          end if;
        else
          if (w_output_ready = '1') then
            r_read_done <= to_stdlogic(r_read_index_curr = (r_read_index_last - 1));

            if (r_read_index_curr /= r_read_index_last) then
              r_read_index_curr <= r_read_index_curr + 1;
            else
              r_read_index_curr <= (others => '-');
              r_read_active <= '0';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  w_read_index_first <= unsigned(w_frame_fifo_rd_data(BUFFER_ADDR_WIDTH - 1 downto 0));
  w_frame_fifo_rd_en <= w_output_ready and r_read_active and to_stdlogic(r_read_index_curr = r_read_index_last);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_valid  <= (others => '0');
        r_read_last   <= (others => '0');
      else
        if (w_output_ready = '1') then
          r_read_valid  <= r_read_valid(0)  & r_read_active;
          r_read_last   <= r_read_last(0)   & r_read_done;
        end if;
      end if;
    end if;
  end process;

  i_frame_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH        => FRAME_DEPTH,
    FIFO_WIDTH        => FRAME_FIFO_WIDTH,
    ALMOST_FULL_LEVEL => FRAME_FIFO_ALMOST_FULL_LEVEL
  )
  port map (
    Clk         => Clk,
    Rst         => Rst,

    Wr_en       => r_frame_fifo_wr_en,
    Wr_data     => r_frame_fifo_wr_data,
    Almost_full => w_frame_fifo_almost_full,
    Full        => open,

    Rd_en       => w_frame_fifo_rd_en,
    Rd_data     => w_frame_fifo_rd_data,
    Empty       => w_frame_fifo_empty,

    Overflow    => open,
    Underflow   => open
  );

  i_data_mem : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => BUFFER_ADDR_WIDTH,
    DATA_WIDTH  => BUFFER_DATA_WIDTH,
    LATENCY     => BUFFER_LATENCY
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_buffer_wr_en,
    Wr_addr   => r_buffer_wr_addr,
    Wr_data   => r_buffer_wr_data,

    Rd_en     => w_output_ready,
    Rd_reg_ce => w_output_ready,
    Rd_addr   => r_read_index_curr,
    Rd_data   => w_buffer_rd_data
  );

  Output_data   <= w_buffer_rd_data;
  Output_valid  <= r_read_valid(1);
  Output_last   <= r_read_last(1);

  w_output_ready <= Output_ready or not(r_read_valid(1));

end architecture rtl;
