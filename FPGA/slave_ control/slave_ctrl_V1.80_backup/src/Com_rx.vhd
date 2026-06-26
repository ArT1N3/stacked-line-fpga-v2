--=============================================================================
-- com_rx - UART字节接收器（8倍过采样DDR逻辑）
--=============================================================================
-- 功能：
--   从din引脚接收单个UART字节（1起始+8数据+1停止）。
--   使用双数据率（DDR）时钟进行8倍过采样。
--
-- UART字节时序（标准8N1格式）：
--   din（空闲=1）: ─┐St│D0│D1│D2│D3│D4│D5│D6│D7│Sp┐──
--                  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
--                  │← 1位 ≈ 8.68us @115200波特 →│
--
-- 8倍过采样方案（DDR双沿采样）：
--   输入时钟：约961.5kHz（周期≈1.04us）
--   一个UART位≈8.68us → 每比特约8.3个时钟周期
--   q计数器（0-7）将UART位分为8个相位：
--     q=0,1   → 位周期开始
--     q=2,3,4 → 中间（ck的采样窗口）
--     q=3,4,5 → 中间（ck2的采样窗口，与ck错开1个相位）
--     q=6,7   → 位周期结束
--
-- 相位时钟（在falling_edge上从q计数器生成）：
--   ck  = '1' 当 q∈{3,4} → ck的上升沿在q=3
--   ck2 = '1' 当 q∈{4,5} → ck2的上升沿在q=4
--   ck和ck2错开1个相位 → 实现DDR风格的双沿采样
--
-- 位组装（q2计数器0-10跟踪字节内的位位置）：
--   q2=0     → 起始位之前
--   q2=1     → 起始位采样
--   q2=2-9   → 数据位D0-D7
--   q2=10    → 停止位/字节结束
--
-- 输出时序：
--   dat[7:0]  → 在falling_edge(ck)上，q2=9时寄存（所有数据位就绪）
--   rst_byte  → 在falling_edge(ck2)上，q2>=9时置位 → 字节完成
--   lk        → rst_byte（锁存脉冲：'1'=字节就绪可读取）
--   busy      → 从检测到起始位到字节完成期间保持'1'
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity com_rx is
  port (
    clk  : in  std_logic;          -- 约961.5kHz波特率时钟（8倍过采样）
    din  : in  std_logic;          -- UART RX串行输入
    dat  : out std_logic_vector(7 downto 0);  -- 接收到的字节
    busy : out std_logic;          -- 正在接收字节时为'1'
    lk   : out std_logic           -- 字节锁存脉冲（字节就绪时为'1'）
  );
end entity com_rx;

architecture rtl of com_rx is

  signal q       : unsigned(2 downto 0) := (others => '0');  -- 相位计数器0-7
  signal q2      : unsigned(3 downto 0) := (others => '0');  -- 位计数器0-10
  signal da      : std_logic_vector(7 downto 0) := (others => '0'); -- 字节组装寄存器
  signal ck      : std_logic := '0';   -- 第一相位时钟（q=3,4时有效）
  signal ck2     : std_logic := '0';   -- 第二相位时钟（q=4,5时有效）
  signal dax     : std_logic := '0';   -- 备用采样（未使用）
  signal bsy     : std_logic := '0';   -- 忙标志
  signal rst_byte : std_logic := '0';  -- 字节完成标志

begin

  -- 忙标志控制：起始位（din下降沿）置位，字节完成时清除
  process (clk)
  begin
    if rising_edge(clk) then
      if din = '0' then bsy <= '1';        -- 检测到起始位
      elsif rst_byte = '1' then bsy <= '0'; -- 字节完成
      end if;
    end if;
  end process;

  -- DDR过采样时钟生成（仅在bsy='1'时运行）
  process (clk, bsy)
  begin
    if bsy = '0' then
      q  <= (others => '0'); ck <= '0'; ck2 <= '0';
    else
      if rising_edge(clk) then
        if q < 7 then q <= q + 1; else q <= (others => '0'); end if;
      end if;
      if falling_edge(clk) then
        if q > 2 and q < 5 then ck <= '1'; else ck <= '0'; end if;
      end if;
      if falling_edge(clk) then
        if q > 3 and q < 6 then ck2 <= '1'; else ck2 <= '0'; end if;
      end if;
    end if;
  end process;

  -- 位采样与字节组装
  process (ck, ck2, bsy)
  begin
    if bsy = '0' then q2 <= (others => '0');
    else
      if rising_edge(ck) then        -- 位计数器递增
        if q2 < 10 then q2 <= q2 + 1; end if;
      end if;
      if rising_edge(ck2) then       -- 在ck2上升沿采样din
        if    q2 <= "0001" then dax <= din;      -- 起始位
        elsif q2 = "0010" then da(0) <= din;     -- 数据位0（LSB）
        elsif q2 = "0011" then da(1) <= din;     -- 数据位1
        elsif q2 = "0100" then da(2) <= din;     -- 数据位2
        elsif q2 = "0101" then da(3) <= din;     -- 数据位3
        elsif q2 = "0110" then da(4) <= din;     -- 数据位4
        elsif q2 = "0111" then da(5) <= din;     -- 数据位5
        elsif q2 = "1000" then da(6) <= din;     -- 数据位6
        elsif q2 = "1001" then da(7) <= din;     -- 数据位7（MSB）
        else dax <= din; end if;
      end if;
      if falling_edge(ck) then       -- 字节输出
        if q2 = "1001" then dat <= da; end if;
      end if;
      if falling_edge(ck2) then      -- 字节完成标志
        if q2 >= "1001" then rst_byte <= '1'; else rst_byte <= '0'; end if;
      end if;
    end if;
  end process;

  lk <= rst_byte;
  busy <= bsy;

end architecture rtl;
