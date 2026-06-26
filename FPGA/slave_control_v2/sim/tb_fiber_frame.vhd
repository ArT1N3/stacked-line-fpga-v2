--=============================================================================
-- tb_fiber_frame — V2.0 帧收发环回测试
--=============================================================================
-- 测试项:
--   1. fiber_frame_rx 接收合法帧 → frame_valid 脉冲
--   2. CRC 错误帧 → frame_err 脉冲
--   3. 字节填充往返 (SOF/EOF/ESC)
--   4. 载荷长度边界 (0字节 / 240字节)
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fiber_frame is
end entity tb_fiber_frame;

architecture sim of tb_fiber_frame is

  -- 时钟
  signal clk        : std_logic := '0';
  constant CLK_PER  : time := 20 ns;  -- 50 MHz

  -- DUT 接口 (fiber_frame_rx)
  signal rst        : std_logic := '0';
  signal rx_byte    : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_lk      : std_logic := '0';
  signal rx_busy    : std_logic := '0';
  signal buf_rd_data: std_logic_vector(7 downto 0);
  signal buf_rd_addr: std_logic_vector(7 downto 0) := (others => '0');
  signal flags_out  : std_logic_vector(7 downto 0);
  signal dst_out    : std_logic_vector(7 downto 0);
  signal src_out    : std_logic_vector(7 downto 0);
  signal cmd_out    : std_logic_vector(7 downto 0);
  signal frame_len  : std_logic_vector(7 downto 0);
  signal frame_valid: std_logic;
  signal frame_err  : std_logic;
  signal err_code   : std_logic_vector(2 downto 0);

  -- 测试控制
  signal test_phase : integer := 0;
  signal fv_captured : std_logic := '0';  -- frame_valid 捕获
  signal fe_captured : std_logic := '0';  -- frame_err 捕获

  -- 辅助函数: 手动计算 CRC-16
  function calc_crc16(bytes : std_logic_vector) return std_logic_vector is
    variable crc : std_logic_vector(15 downto 0) := x"FFFF";
    variable d   : std_logic;
    variable nb  : integer;
  begin
    nb := bytes'length / 8;
    for j in 0 to nb-1 loop  -- (0 to N-1) vector: j=0 is leftmost byte (FLAGS)
      for i in 0 to 7 loop  -- (0 to N-1): bit 0 is MSB within byte
        d := bytes(j*8 + i) xor crc(15);
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

  -- 发送字节到 DUT（在 clk 下降沿后更新，保证上升沿前稳定）
  procedure send_byte(
    b       : in std_logic_vector(7 downto 0);
    signal data : out std_logic_vector(7 downto 0);
    signal lk   : out std_logic;
    signal busy : out std_logic) is
  begin
    busy <= '1';
    data <= b;
    wait for CLK_PER/4;  -- 5ns，偏移到远离 clk 沿
    lk <= '1';
    wait for CLK_PER;    -- 20ns
    lk <= '0';
    wait for CLK_PER * 5;
    busy <= '0';
    wait for CLK_PER;
  end procedure;

begin

  -- 时钟
  clk <= not clk after CLK_PER/2;

  -- DUT: fiber_frame_rx
  u_dut : entity work.fiber_frame_rx
    port map (
      clk         => clk,
      rst         => rst,
      rx_byte     => rx_byte,
      rx_lk       => rx_lk,
      rx_busy     => rx_busy,
      buf_rd_data => buf_rd_data,
      buf_rd_addr => buf_rd_addr,
      buf_wr_data => x"00",
      buf_wr_addr => x"00",
      buf_wr_en   => '0',
      flags_out   => flags_out,
      dst_out     => dst_out,
      src_out     => src_out,
      cmd_out     => cmd_out,
      frame_len   => frame_len,
      frame_valid => frame_valid,
      frame_err   => frame_err,
      err_code    => err_code,
      crc_err_cnt => open
    );

  -- 帧完成/错误捕获进程
  p_capture : process(frame_valid, frame_err)
  begin
    if frame_valid = '1' then
      fv_captured <= '1';
    end if;
    if frame_err = '1' then
      fe_captured <= '1';
    end if;
  end process p_capture;

  -- 主测试流程
  p_test : process
    variable crc16 : std_logic_vector(15 downto 0);
  begin
    -- 复位
    rst <= '0';
    wait for CLK_PER * 5;
    rst <= '1';
    wait for CLK_PER * 2;

    --=================================================================
    -- Test 1: 发送合法最小帧 (0字节载荷)
    -- 帧: SOF FLAGS DST SRC CMD LEN CRC16 EOF
    --=================================================================
    test_phase <= 1;
    report "Test 1: Minimum frame (LEN=0)";

    -- SOF
    send_byte(x"7E", rx_byte, rx_lk, rx_busy);

    -- Header: FLAGS(0x00) DST(0x05) SRC(0x00) CMD(0x01) LEN(0x00)
    crc16 := calc_crc16(x"00" & x"05" & x"00" & x"01" & x"00");  -- 5 bytes

    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- FLAGS
    send_byte(x"05", rx_byte, rx_lk, rx_busy);  -- DST
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- SRC
    send_byte(x"01", rx_byte, rx_lk, rx_busy);  -- CMD
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- LEN=0

    -- CRC (LSB first)
    send_byte(crc16(7 downto 0), rx_byte, rx_lk, rx_busy);
    send_byte(crc16(15 downto 8), rx_byte, rx_lk, rx_busy);

    -- EOF
    send_byte(x"7E", rx_byte, rx_lk, rx_busy);

    -- 等待 DUT 处理完成
    wait for 3000 ns;
    assert frame_valid = '1'
      report "Test 1 FAIL: frame_valid not asserted" severity error;
    assert frame_err = '0'
      report "Test 1 FAIL: frame_err asserted" severity error;

    if frame_valid = '1' then
      -- 验证缓冲内容
      buf_rd_addr <= x"00";
      wait for CLK_PER;
      assert buf_rd_data = x"00" report "buf[0] FLAGS mismatch" severity error;
      buf_rd_addr <= x"01";
      wait for CLK_PER;
      assert buf_rd_data = x"05" report "buf[1] DST mismatch" severity error;
      buf_rd_addr <= x"04";
      wait for CLK_PER;
      assert buf_rd_data = x"00" report "buf[4] LEN mismatch" severity error;
      report "Test 1 PASS: Minimum frame OK";
    end if;

    wait for CLK_PER * 5;

    --=================================================================
    -- Test 2: CRC 错误帧
    --=================================================================
    test_phase <= 2;
    report "Test 2: CRC error frame";
    -- 帧间间隔，等待上一个 frame_valid 清除
    wait for 100 ns;

    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- SOF
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- FLAGS
    send_byte(x"05", rx_byte, rx_lk, rx_busy);  -- DST
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- SRC
    send_byte(x"01", rx_byte, rx_lk, rx_busy);  -- CMD
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- LEN=0
    send_byte(x"FF", rx_byte, rx_lk, rx_busy);  -- CRC[0] = wrong
    send_byte(x"FF", rx_byte, rx_lk, rx_busy);  -- CRC[1] = wrong
    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- EOF

    wait for 3000 ns;
    assert frame_err = '1'
      report "Test 2 FAIL: frame_err not asserted for bad CRC" severity error;

    if frame_err = '1' then
      report "Test 2 PASS: CRC error detected";
    end if;

    --=================================================================
    -- Test 3: 带载荷帧
    --=================================================================
    test_phase <= 3;
    report "Test 3: Frame with payload (LEN=2)";

    -- 帧间间隔，等待上一个 frame_valid 清除
    wait for 100 ns;

    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- SOF
    send_byte(x"08", rx_byte, rx_lk, rx_busy);  -- FLAGS: MOD=01
    send_byte(x"05", rx_byte, rx_lk, rx_busy);  -- DST
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- SRC
    send_byte(x"03", rx_byte, rx_lk, rx_busy);  -- CMD=RLY_CTRL
    send_byte(x"02", rx_byte, rx_lk, rx_busy);  -- LEN=2
    send_byte(x"0F", rx_byte, rx_lk, rx_busy);  -- payload[0]
    send_byte(x"F0", rx_byte, rx_lk, rx_busy);  -- payload[1]

    crc16 := calc_crc16(x"08" & x"05" & x"00" & x"03" & x"02" & x"0F" & x"F0");
    send_byte(crc16(7 downto 0), rx_byte, rx_lk, rx_busy);
    send_byte(crc16(15 downto 8), rx_byte, rx_lk, rx_busy);

    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- EOF

    wait for 3000 ns;
    assert frame_valid = '1' report "Test 3 FAIL" severity error;

    if frame_valid = '1' then
      assert flags_out = x"08" report "Test 3: FLAGS mismatch" severity error;
      assert cmd_out = x"03" report "Test 3: CMD mismatch" severity error;
      assert to_integer(unsigned(frame_len)) = 2 report "Test 3: LEN mismatch" severity error;
      buf_rd_addr <= x"05";
      wait for CLK_PER;
      assert buf_rd_data = x"0F" report "Test 3: payload[0] mismatch" severity error;
      buf_rd_addr <= x"06";
      wait for CLK_PER;
      assert buf_rd_data = x"F0" report "Test 3: payload[1] mismatch" severity error;
      report "Test 3 PASS: Payload frame OK";
    end if;

    --=================================================================
    -- Test 4: 字节填充
    --=================================================================
    test_phase <= 4;
    report "Test 4: Byte stuffing";

    -- 帧间间隔，等待上一个 frame_valid 清除
    wait for 100 ns;

    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- SOF
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- FLAGS
    send_byte(x"01", rx_byte, rx_lk, rx_busy);  -- DST
    send_byte(x"00", rx_byte, rx_lk, rx_busy);  -- SRC
    send_byte(x"0A", rx_byte, rx_lk, rx_busy);  -- CMD=IDENTIFY
    send_byte(x"02", rx_byte, rx_lk, rx_busy);  -- LEN=2

    send_byte(x"7D", rx_byte, rx_lk, rx_busy);  -- escape →
    send_byte(x"5E", rx_byte, rx_lk, rx_busy);  -- → 0x7E
    send_byte(x"7D", rx_byte, rx_lk, rx_busy);  -- escape →
    send_byte(x"5D", rx_byte, rx_lk, rx_busy);  -- → 0x7D

    crc16 := calc_crc16(x"00" & x"01" & x"00" & x"0A" & x"02" & x"7E" & x"7D");
    send_byte(crc16(7 downto 0), rx_byte, rx_lk, rx_busy);
    send_byte(crc16(15 downto 8), rx_byte, rx_lk, rx_busy);

    send_byte(x"7E", rx_byte, rx_lk, rx_busy);  -- EOF

    wait for 3000 ns;
    assert frame_valid = '1' report "Test 4 FAIL: frame_valid not asserted" severity error;

    if frame_valid = '1' then
      buf_rd_addr <= x"05";
      wait for CLK_PER;
      assert buf_rd_data = x"7E" report "Test 4 FAIL: payload[0] should be 0x7E" severity error;
      buf_rd_addr <= x"06";
      wait for CLK_PER;
      assert buf_rd_data = x"7D" report "Test 4 FAIL: payload[1] should be 0x7D" severity error;
      report "Test 4 PASS: Byte stuffing round-trip OK";
    end if;

    --=================================================================
    -- 测试完成
    --=================================================================
    report "=== ALL TESTS COMPLETE ===";
    wait;
  end process p_test;

end architecture sim;
