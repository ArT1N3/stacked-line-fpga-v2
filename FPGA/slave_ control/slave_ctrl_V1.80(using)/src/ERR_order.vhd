--=============================================================================
-- err_order - 脉宽指令检测器
--=============================================================================
-- 功能：
--   测量输入信号（来自主控的RXD）的低电平脉宽，输出计数值
--   （100ns为单位）供指令解码。检测上升沿用于充电完成信号。
--
-- 测量方法：
--   1. 3级同步器防止异步RXD输入的亚稳态。
--   2. 边沿检测器从reg2/reg3产生posedge/negedge标志。
--   3. 100ns采样时钟（10MHz，50MHz 5分频）用于脉冲计数。
--   4. 13位计数器计数低电平脉宽，最大819.1us。
--   5. 上升沿或500us超时时，锁存计数值并置位cmd_flag。
--
-- 状态机：
--   unlock → 正在测量脉宽
--     ↓ posedge 或 计数>=500us
--   lock   → 保持结果，等待ERR_ctrl清除rst_detecor
--     ↓ rst='0'（来自ERR_ctrl）
--   unlock → 准备好下一次测量
--
-- 时序：
--   系统时钟：50MHz（20ns周期）
--   采样时钟：10MHz（100ns周期，5个系统时钟）
--   脉宽分辨率：100ns
--   最大可测脉宽：2^13 * 100ns = 819.1us
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity err_order is
  port (
    clk          : in  std_logic;    -- 50MHz系统时钟
    rst          : in  std_logic;    -- 来自ERR_ctrl的复位（低有效）
    input        : in  std_logic;    -- 来自主控的RXD信号
    cmd_flag     : out std_logic;    -- 脉宽测量有效脉冲
    cmd_bus      : out std_logic_vector(12 downto 0); -- 脉宽（100ns单位）
    posedge_out  : out std_logic     -- 检测到上升沿（充电完成）
  );
end entity err_order;

architecture rtl of err_order is

  -- 锁存状态：防止ERR_ctrl处理结果前重新触发
  type dt_state is (unlock, lock);
  signal state : dt_state;

  -- 3级输入同步器寄存器（亚稳态保护）
  signal reg1 : std_logic;  -- 第1级：采样原始输入
  signal reg2 : std_logic;  -- 第2级：延迟1个时钟
  signal reg3 : std_logic;  -- 第3级：延迟2个时钟（用于边沿检测）

  -- 边沿检测标志（锁存直到下一个相反边沿）
  signal posedge      : std_logic;  -- reg2='1' 且 reg3='0'
  signal negedge      : std_logic;  -- reg2='0' 且 reg3='1'
  signal posedge_buf  : std_logic;  -- 独立于状态跟随边沿

  -- 100ns采样时钟发生器
  signal sample_en    : std_logic;       -- 采样脉冲（每100ns一个周期）
  signal sample_count : integer range 0 to 4;  -- 5分频计数器

  -- 脉宽测量
  signal pulse_count  : unsigned(12 downto 0); -- 运行计数器（100ns单位）
  signal pulse_cache  : unsigned(12 downto 0); -- 锁存的输出结果

begin

  -- ========================================================================
  -- 3级输入同步器
  -- 防止异步RXD信号的亚稳态。
  -- 复位到'1'因为RXD空闲状态为高电平（mark）。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      reg1 <= '1';
    elsif rising_edge(clk) then
      reg1 <= input;              -- 第1级：原始采样
    end if;
  end process;

  process (clk, rst)
  begin
    if rst = '0' then
      reg2 <= '1';
    elsif rising_edge(clk) then
      reg2 <= reg1;               -- 第2级：延迟1个时钟
    end if;
  end process;

  process (clk, rst)
  begin
    if rst = '0' then
      reg3 <= '1';
    elsif rising_edge(clk) then
      reg3 <= reg2;               -- 第3级：延迟2个时钟
    end if;
  end process;

  -- ========================================================================
  -- 边沿检测（锁存，状态门控）
  -- 使用不完整的IF语句锁存边沿标志。
  -- posedge: reg2=1, reg3=0 → RXD刚变高
  -- negedge: reg2=0, reg3=1 → RXD刚变低
  -- 仅在unlock状态下有效（防止lock期间的假边沿）。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      posedge <= '0';
      negedge <= '0';
    elsif rising_edge(clk) then
      if reg2 = '1' and reg3 = '0' and state = unlock then
        posedge <= '1';            -- 锁存上升沿标志
        negedge <= '0';
      end if;
      if reg2 = '0' and reg3 = '1' and state = unlock then
        posedge <= '0';
        negedge <= '1';            -- 锁存下降沿标志
      end if;
    end if;
  end process;

  -- ========================================================================
  -- posedge_out: 独立于状态跟随输入边沿
  -- 被ERR_ctrl用于检测充电完成（RXD上升沿）。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      posedge_buf <= '0';
    elsif rising_edge(clk) then
      if reg2 = '1' and reg3 = '0' then
        posedge_buf <= '1';        -- 任何上升沿都锁存
      end if;
    end if;
  end process;
  posedge_out <= posedge_buf;

  -- ========================================================================
  -- 采样时钟发生器：100ns周期（10MHz）
  -- 50MHz / 5 = 10MHz → 每次采样100ns
  -- 仅在unlock状态且negedge有效（低脉冲期间）运行。
  -- sample_en每100ns保持1个时钟周期的高电平。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      sample_en    <= '0';
      sample_count <= 0;
    elsif rising_edge(clk) then
      if state = unlock and negedge = '1' then
        if sample_count = 4 then
          sample_en    <= '1';     -- 每5个时钟产生一次脉冲
          sample_count <= 0;
        else
          sample_count <= sample_count + 1;
          sample_en    <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ========================================================================
  -- 低电平脉宽计数器
  -- 在RXD为低电平（negedge有效）时，每次sample_en脉冲递增。
  -- 以100ns为单位计数，在8191（819.1us）处饱和。
  -- 13位计数器：最大值=8191 → 最大可测脉宽819.1us。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      pulse_count <= (others => '0');
    elsif rising_edge(clk) then
      if state = unlock and sample_en = '1' and negedge = '1' then
        if pulse_count < "1111111111111" then
          pulse_count <= pulse_count + 1;   -- 每100ns递增
        end if;
        -- 否则：饱和在最大值（防止溢出）
      end if;
    end if;
  end process;

  -- ========================================================================
  -- 脉宽寄存器与状态机
  -- 在以下情况锁存pulse_count：
  --   1. posedge（RXD变高 → 低脉冲正常结束）
  --   2. 超时（计数>=500us → 安全锁存，防止死锁）
  -- 锁存后进入lock状态，直到ERR_ctrl取消rst的置位。
  -- cmd_flag输出高脉冲告诉ERR_ctrl有新的测量数据就绪。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      pulse_cache <= (others => '0');
      cmd_flag    <= '0';
      state       <= unlock;
    elsif rising_edge(clk) then
      if state = unlock then
        if posedge = '1' or pulse_count >= "1001110001000" then
          -- posedge: 脉冲结束 → 锁存计数值
          -- 计数>=5000（500us @100ns）: 超时 → 安全锁存
          pulse_cache <= pulse_count;
          cmd_flag    <= '1';       -- 脉冲：测量有效
          state       <= lock;      -- 等待ERR_ctrl的rst信号
        end if;
      else
        cmd_flag <= '0';            -- lock状态下取消脉冲
      end if;
    end if;
  end process;

  -- 输出锁存的脉宽测量值
  cmd_bus <= std_logic_vector(pulse_cache);

end architecture rtl;
