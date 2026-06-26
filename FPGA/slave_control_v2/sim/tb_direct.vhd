library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_direct is
end entity;

architecture sim of tb_direct is
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal rx_byte : std_logic_vector(7 downto 0);
  signal rx_lk   : std_logic := '0';
  signal fv, fe  : std_logic;
  signal ec      : std_logic_vector(2 downto 0);
  signal step    : integer := 0;
  signal gap     : integer := 0;

  function crc16(data : std_logic_vector) return std_logic_vector is
    variable crc : std_logic_vector(15 downto 0) := x"FFFF"; variable d : std_logic; variable nb : integer;
  begin
    nb := data'length / 8;
    for j in 0 to nb-1 loop for i in 0 to 7 loop  -- (0 to N-1) vec: j=0 leftmost byte, i=0 MSB
      d := data(j*8 + i) xor crc(15);
      crc(15 downto 13) := crc(14 downto 12); crc(12) := d xor crc(11);
      crc(11 downto 6) := crc(10 downto 5); crc(5) := d xor crc(4);
      crc(4 downto 1) := crc(3 downto 0); crc(0) := d;
    end loop; end loop;
    return crc;
  end function;
begin
  clk <= not clk after 10 ns;  -- 50 MHz (T=20ns)

  u_dut : entity work.fiber_frame_rx
    port map (clk=>clk, rst=>rst, rx_byte=>rx_byte, rx_lk=>rx_lk,
      rx_busy=>'1', buf_rd_data=>open, buf_rd_addr=>x"00",
      buf_wr_data=>x"00", buf_wr_addr=>x"00", buf_wr_en=>'0',
      flags_out=>open, dst_out=>open, src_out=>open, cmd_out=>open,
      frame_len=>open, frame_valid=>fv, frame_err=>fe, err_code=>ec,
      crc_err_cnt=>open);

  -- Single process: drives everything
  p_main : process
    variable c : std_logic_vector(15 downto 0);
    procedure send_byte(b : std_logic_vector(7 downto 0)) is
    begin
      rx_byte <= b;
      wait until rising_edge(clk);
      rx_lk <= '1';
      wait until rising_edge(clk);
      rx_lk <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);  -- 2 cycle gap
    end procedure;
  begin
    rst <= '0'; wait for 100 ns; rst <= '1'; wait for 40 ns;

    c := crc16(x"00" & x"05" & x"00" & x"01" & x"00");

    send_byte(x"7E"); send_byte(x"00"); send_byte(x"05");
    send_byte(x"00"); send_byte(x"01"); send_byte(x"00");
    send_byte(c(7 downto 0)); send_byte(c(15 downto 8));
    send_byte(x"7E");

    -- Wait for result
    wait for 5000 ns;

    if fv='1' then report "PASS";
    elsif fe='1' then report "FAIL: frame_err=" & integer'image(to_integer(unsigned(ec)));
    else report "FAIL: timeout"; end if;
    wait;
  end process;
end architecture;
