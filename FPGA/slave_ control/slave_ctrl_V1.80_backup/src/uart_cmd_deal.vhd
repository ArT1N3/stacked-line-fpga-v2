--=============================================================================
-- uart_cmd_deal - UART指令解码执行单元
--=============================================================================
-- 功能：
--   接收解析后的UART帧数据（confm + cmd + 8×16位数据字），
--   为10通道分控板执行配置指令。
--
-- 指令：
--   cmd = x"55"（ASCII 'U'）→ "更新"/使能配置
--     将接收到的128位数据（q）锁存到持久缓冲区（q_buf）。
--     保持rst_err='1'（故障检测器保持活动）。
--     用于发送每通道的使能/触发配置。
--
--   cmd = x"01"（SOH）→ 故障复位
--     清除rst_err（取消故障检测器复位）。
--     保留q_buf（保持使能配置不变）。
--     rst_err设为NOT(confm)，在confm有效时输出低脉冲。
--
-- 数据打包（128位内部总线）：
--   8个接收到的16位数据字拼接成一个128位寄存器q：
--     q = {data15, data13, data11, data9, data7, data5, data3, data1}
--   可配置最多9组×10位（使用90位，38位未使用）。
--
-- 地址路由（多节点）：
--   板卡地址选择q_buf中哪个10位片段路由到输出通道：
--     "0001" → q_buf[9:0]    "0110" → q_buf[59:50]
--     "0010" → q_buf[19:10]  "0111" → q_buf[69:60]
--     ...以此类推到"1001" → q_buf[89:80]
--
-- 输出极性：
--   en_work  = q_buf片段（高有效）
--   en_state = q_buf片段（高有效）
--   en_trig  = NOT q_buf片段（低有效，外部驱动电路要求）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity uart_cmd_deal is
  port (
    rst      : in  std_logic;       -- 异步复位（低有效）
    clk      : in  std_logic;       -- 50MHz系统时钟
    confm    : in  std_logic;       -- UART帧确认脉冲（1周期）
    cmd      : in  std_logic_vector(7 downto 0);  -- 指令字节
    data1    : in  std_logic_vector(15 downto 0); -- 数据字（低位组）
    data3, data5, data7, data9   : in  std_logic_vector(15 downto 0);
    data11, data13, data15       : in  std_logic_vector(15 downto 0);
    address  : in  std_logic_vector(3 downto 0);  -- 板卡地址（1-9）
    rst_err  : out std_logic;       -- 故障检测器复位（低有效）
    en_work  : out std_logic_vector(10 downto 1); -- 通道使能输出
    en_trig  : out std_logic_vector(10 downto 1); -- 通道触发（取反）
    en_state : out std_logic_vector(10 downto 1)  -- 通道使能状态
  );
end entity uart_cmd_deal;

architecture rtl of uart_cmd_deal is
  signal q       : std_logic_vector(127 downto 0); -- 临时数据锁存
  signal q_buf   : std_logic_vector(127 downto 0); -- 持久使能数据缓冲
  signal cmd_buf : std_logic_vector(7 downto 0);   -- 锁存的指令字节
begin

  -- p1: confm上升沿锁存数据（由confm自身作为时钟）
  p1: process (confm, rst)
  begin
    if rst = '0' then q <= (others => '0'); cmd_buf <= (others => '0');
    elsif rising_edge(confm) then
      q <= data15 & data13 & data11 & data9 & data7 & data5 & data3 & data1;
      cmd_buf <= cmd;
    end if;
  end process p1;

  -- p2: 指令执行（同步于系统时钟）
  -- x"55": 复制q→q_buf，保持rst_err='1'
  -- x"01": rst_err <= NOT(confm)，产生故障复位脉冲
  p2: process (clk, rst)
  begin
    if rst = '0' then q_buf <= (others => '0'); rst_err <= '1';
    elsif rising_edge(clk) then
      if cmd_buf = x"55" then q_buf <= q; rst_err <= '1';
      elsif cmd_buf = x"01" then rst_err <= not confm; end if;
    end if;
  end process p2;

  -- p3: 基于地址的输出路由（组合逻辑）
  -- 将q_buf的10位片段分配到输出端口，en_trig取反
  p3: process (rst, q_buf, address)
  begin
    if rst = '0' then
      en_state <= (others => '1'); en_trig <= (others => '0'); en_work <= (others => '0');
    else
      case address is
        when "0001" => en_state <= q_buf(9 downto 0);   en_work <= q_buf(9 downto 0);   en_trig <= not q_buf(9 downto 0);
        when "0010" => en_state <= q_buf(19 downto 10); en_work <= q_buf(19 downto 10); en_trig <= not q_buf(19 downto 10);
        when "0011" => en_state <= q_buf(29 downto 20); en_work <= q_buf(29 downto 20); en_trig <= not q_buf(29 downto 20);
        when "0100" => en_state <= q_buf(39 downto 30); en_work <= q_buf(39 downto 30); en_trig <= not q_buf(39 downto 30);
        when "0101" => en_state <= q_buf(49 downto 40); en_work <= q_buf(49 downto 40); en_trig <= not q_buf(49 downto 40);
        when "0110" => en_state <= q_buf(59 downto 50); en_work <= q_buf(59 downto 50); en_trig <= not q_buf(59 downto 50);
        when "0111" => en_state <= q_buf(69 downto 60); en_work <= q_buf(69 downto 60); en_trig <= not q_buf(69 downto 60);
        when "1000" => en_state <= q_buf(79 downto 70); en_work <= q_buf(79 downto 70); en_trig <= not q_buf(79 downto 70);
        when "1001" => en_state <= q_buf(89 downto 80); en_work <= q_buf(89 downto 80); en_trig <= not q_buf(89 downto 80);
        when others => en_state <= q_buf(9 downto 0);   en_work <= q_buf(9 downto 0);   en_trig <= not q_buf(9 downto 0);
      end case;
    end if;
  end process p3;

end architecture rtl;
