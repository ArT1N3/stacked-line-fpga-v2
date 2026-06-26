library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sync is
end entity;

architecture sim of tb_sync is
  signal clk       : std_logic := '0';
  signal rst       : std_logic := '0';
  signal rx_byte   : std_logic_vector(7 downto 0) := x"00";
  signal rx_lk     : std_logic := '0';
  signal rx_busy   : std_logic := '1';
  signal fv, fe    : std_logic;
  signal ec        : std_logic_vector(2 downto 0);
  signal byte_cnt  : integer := 0;
  signal send_now  : std_logic := '0';

  type byte_arr is array(0 to 31) of std_logic_vector(7 downto 0);
  signal frame     : byte_arr;
  signal frame_len : integer := 0;

  function crc16(data : std_logic_vector) return std_logic_vector is
    variable crc : std_logic_vector(15 downto 0) := x"FFFF";
    variable d : std_logic; variable nb : integer;
  begin
    nb := data'length / 8;
    for j in 0 to nb-1 loop  -- (0 to N-1) vector: j=0 is leftmost byte (FLAGS)
      for i in 0 to 7 loop  -- (0 to N-1): bit 0 is MSB within byte
        d := data(j*8 + i) xor crc(15);
        crc(15 downto 13) := crc(14 downto 12);
        crc(12) := d xor crc(11);
        crc(11 downto 6) := crc(10 downto 5);
        crc(5) := d xor crc(4);
        crc(4 downto 1) := crc(3 downto 0);
        crc(0) := d;
      end loop;
    end loop;
    return crc;
  end function;
begin
  clk <= not clk after 10 ns;  -- 50 MHz (T=20ns)

  u_dut : entity work.fiber_frame_rx
    port map (clk=>clk, rst=>rst, rx_byte=>rx_byte, rx_lk=>rx_lk,
      rx_busy=>rx_busy, buf_rd_data=>open, buf_rd_addr=>x"00",
      buf_wr_data=>x"00", buf_wr_addr=>x"00", buf_wr_en=>'0',
      flags_out=>open, dst_out=>open, src_out=>open, cmd_out=>open,
      frame_len=>open, frame_valid=>fv, frame_err=>fe, err_code=>ec,
      crc_err_cnt=>open);

  -- Synchronous byte sender: rx_lk 1 cycle on, 3 cycles off between bytes
  p_sender : process(clk, rst)
    variable gap_cnt : integer := 0;
  begin
    if rst = '0' then
      byte_cnt <= 0; rx_lk <= '0'; rx_byte <= x"00"; gap_cnt := 0;
    elsif rising_edge(clk) then
      rx_lk <= '0';
      if send_now = '1' and byte_cnt < frame_len then
        if gap_cnt = 0 then
          rx_byte <= frame(byte_cnt);
          rx_lk <= '1';
          byte_cnt <= byte_cnt + 1;
          gap_cnt := 4;  -- 4 cycle gap between bytes (~80ns)
        else
          gap_cnt := gap_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  p_test : process
    variable c : std_logic_vector(15 downto 0);
  begin
    -- reset
    rst <= '0'; wait for 100 ns; rst <= '1'; wait for 40 ns;

    -- Build frame in array
    -- Header: FLAGS(0x00) DST(0x05) SRC(0x00) CMD(0x01) LEN(0x00)
    c := crc16(x"00" & x"05" & x"00" & x"01" & x"00");
    frame(0) <= x"7E"; frame(1) <= x"00"; frame(2) <= x"05";
    frame(3) <= x"00"; frame(4) <= x"01"; frame(5) <= x"00";
    frame(6) <= c(7 downto 0); frame(7) <= c(15 downto 8);
    frame(8) <= x"7E";
    frame_len <= 9;
    wait until rising_edge(clk);

    -- Send all bytes (9 bytes * 5 cycles/byte = 45 cycles = 900ns)
    send_now <= '1';
    wait for 2000 ns;
    send_now <= '0';

    -- Wait for result
    wait for 5000 ns;

    if fv='1' then report "PASS: frame_valid";
    elsif fe='1' then report "FAIL: frame_err code=" & integer'image(to_integer(unsigned(ec)));
    else report "FAIL: timeout"; end if;
    wait;
  end process;
end architecture;
