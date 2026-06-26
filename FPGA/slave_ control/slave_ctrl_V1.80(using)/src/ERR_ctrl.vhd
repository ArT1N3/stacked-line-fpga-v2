--=============================================================================
-- err_ctrl - 脉宽协议指令状态机
--=============================================================================
-- 功能：
--   解码来自err_order的脉宽测量值，控制移位寄存器加载时序，
--   通过多节点总线进行状态上传。
--
-- 指令解码（脉宽由err_order测量，100ns为单位）：
--   180-220 us（1500-2200计数）→ 在线状态查询
--   380-420 us（3800-4200计数）→ 使能状态查询
--   480-520 us（4800-5200计数）→ 充电指令
--
-- 多节点仲裁：
--   每个分控板有唯一地址（1-12）。收到查询指令后，
--   分控根据地址等待相应的偏移延时后再上传状态，避免总线冲突：
--     地址1  →  0 us延时（offset = 0）
--     地址2  → 100 us延时（offset = 5000个时钟周期）
--     地址3  → 200 us延时（offset = 10000个时钟周期）
--     ...
--     每个分控获得100 us的时间窗口（50MHz下5000个时钟周期）。
--
-- 状态机：
--   free  → 空闲，等待指令
--     ↓ cmd_flag
--   on_search    → 在线查询：等待偏移延时，然后移位输出在线状态
--   en_search    → 使能查询：等待偏移延时，然后移位输出使能状态
--   charge       → 充电指令：在充电脉冲期间使能故障检测
--     ↓ posedge（充电完成）
--   charge_search → 充电后：等待偏移延时，移位输出过流状态
--
-- LOAD信号（输出到err_shift_test）：
--   load_1='0' → 移位输出在线状态
--   load_2='0' → 移位输出使能状态
--   load_3='0' → 移位输出过流故障状态
--   全部为'1'  → 空闲（并行加载，不移位）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_ctrl is
  port (
    clk         : in  std_logic;    -- 50MHz系统时钟
    rst         : in  std_logic;    -- 异步复位（低有效）
    cmd_flag    : in  std_logic;    -- 脉宽测量有效脉冲
    cmd_bus     : in  std_logic_vector(12 downto 0); -- 脉宽值（100ns单位）
    shift_done  : in  std_logic;    -- 移位寄存器已完成10位上传
    address     : in  std_logic_vector(3 downto 0);  -- 板卡地址（多节点总线）
    posedge     : in  std_logic;    -- RXD上升沿（充电完成）
    load_1      : out std_logic;    -- '0'=移位在线状态, '1'=保持
    load_2      : out std_logic;    -- '0'=移位使能状态, '1'=保持
    load_3      : out std_logic;    -- '0'=移位过流状态, '1'=保持
    rst_detecor : out std_logic;    -- 复位脉宽检测器（高有效）
    en_charge   : out std_logic     -- 充电期间使能故障检测
  );
end entity err_ctrl;

architecture rtl of err_ctrl is

  -- 状态机：free→查询类型→等待偏移→移位→free
  type work_state is (free, on_search, en_search, charge, charge_search);
  signal state        : work_state;

  -- offset: 基于地址的延时值（50MHz时钟周期数）
  -- 每个分控获得100us窗口：地址N → offset = (N-1) * 5000
  -- offset_count: 与offset比较的运行计数器
  signal offset       : integer range 0 to 65000 := 0;
  signal offset_count : integer range 0 to 65001 := 0;

  -- 缓冲的指令（从cmd_flag脉冲锁存）
  signal cmd_bus_buf  : std_logic_vector(12 downto 0);
  signal cmd_flag_buf : std_logic;  -- 延迟的cmd_flag（1个时钟周期宽）

begin

  -- ========================================================================
  -- 地址到偏移量的映射
  -- 将4位板卡地址转换为多节点仲裁的延时偏移量。
  -- 地址1（offset=0）立即响应，更高地址等待更长时间。
  -- 每级增加5000个周期（50MHz下100us）。
  -- ========================================================================
  process (address)
  begin
    case address is
      when "0001" => offset <= 0;       -- 地址1: 无延时
      when "0010" => offset <= 5000;    -- 地址2: 100us
      when "0011" => offset <= 10000;   -- 地址3: 200us
      when "0100" => offset <= 15000;   -- 地址4: 300us
      when "0101" => offset <= 20000;   -- 地址5: 400us
      when "0110" => offset <= 25000;   -- 地址6: 500us
      when "0111" => offset <= 30000;   -- 地址7: 600us
      when "1000" => offset <= 35000;   -- 地址8: 700us
      when "1001" => offset <= 40000;   -- 地址9: 800us
      when "1010" => offset <= 45000;   -- 地址10: 900us
      when "1011" => offset <= 50000;   -- 地址11: 1000us
      when "1100" => offset <= 55000;   -- 地址12: 1100us
      when others  => offset <= 0;      -- 默认: 无延时
    end case;
  end process;

  -- ========================================================================
  -- 指令锁存（边沿触发）
  -- 在cmd_flag脉冲时捕获脉宽测量值。
  -- cmd_flag_buf恰好保持1个时钟周期的高电平。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      cmd_bus_buf  <= (others => '0');
      cmd_flag_buf <= '0';
    elsif rising_edge(clk) then
      if cmd_flag = '1' then
        cmd_bus_buf  <= cmd_bus;     -- 锁存测量到的脉宽值
        cmd_flag_buf <= '1';         -- 信号：有新指令可用
      else
        cmd_flag_buf <= '0';         -- 1个周期后清除
      end if;
    end if;
  end process;

  -- ========================================================================
  -- 主指令状态机
  --
  -- FREE（空闲）状态：
  --   等待cmd_flag_buf。解码脉宽以确定指令类型。
  --   如果不匹配，保持FREE状态，所有load信号为高（保持模式）。
  --   rst_detecor='1'保持脉宽检测器处于活动状态。
  --
  -- ON_SEARCH / EN_SEARCH状态：
  --   等待offset_count达到基于地址的偏移值，然后将
  --   对应的load信号置低（启动移位）。
  --   移位完成后（shift_done='1'），返回FREE状态。
  --
  -- CHARGE（充电）状态：
  --   等待posedge（RXD上升沿 = 充电完成）。
  --   充电期间：en_charge='1'（故障检测使能），load_3='1'（保持）。
  --   posedge后：转入CHARGE_SEARCH以上传过流状态。
  --
  -- CHARGE_SEARCH状态：
  --   与ON_SEARCH/EN_SEARCH相同的偏移延时逻辑，但针对过流数据。
  --   shift_done后返回FREE状态。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      -- 复位：所有load为高（保持/并行加载模式），空闲状态
      load_1       <= '1';
      load_2       <= '1';
      load_3       <= '1';
      en_charge    <= '0';
      rst_detecor  <= '0';
      state        <= free;
      offset_count <= 0;
    elsif rising_edge(clk) then
      case state is

        -- ================================================================
        -- FREE: 空闲，等待解码指令
        -- ================================================================
        when free =>
          if cmd_flag_buf = '1' then
            -- 解码脉宽以确定指令类型
            if cmd_bus_buf > "0010111011100" and cmd_bus_buf < "0100111000100" then
              -- 1500-2200计数 @100ns = 150-220us → 在线状态查询
              state <= on_search;
            elsif cmd_bus_buf > "0111011011000" and cmd_bus_buf < "1000001101000" then
              -- 3800-4200计数 @100ns = 380-420us → 使能状态查询
              state <= en_search;
            elsif cmd_bus_buf >= "1001011000000" and cmd_bus_buf < "1010001010000" then
              -- 4800-5200计数 @100ns = 480-520us → 充电指令
              state <= charge;
            else
              -- 未识别的脉宽 → 忽略，保持FREE
              state <= free;
              load_1 <= '1'; load_2 <= '1'; load_3 <= '1';
              rst_detecor <= '0';
            end if;
          else
            -- 暂无指令：保持脉宽检测器活动
            rst_detecor <= '1';
            state       <= free;
            load_1 <= '1'; load_2 <= '1'; load_3 <= '1';
          end if;

        -- ================================================================
        -- ON_SEARCH: 上传在线（供电故障）状态
        -- ================================================================
        when on_search =>
          if shift_done = '1' then
            -- 10位全部移位输出 → 完成，返回空闲
            rst_detecor  <= '0';
            load_1       <= '1';
            state        <= free;
            offset_count <= 0;
          else
            -- 仍在移位或等待偏移延时
            rst_detecor <= '1';
            if offset_count >= offset then
              -- 偏移延时已过 → 使能移位（load_1='0'）
              offset_count <= offset_count + 1;
              load_1       <= '0';
              state        <= on_search;
            elsif offset_count = 60001 then
              -- 安全超时：回绕以避免计数器溢出
              offset_count <= offset + 1;
              state        <= on_search;
            else
              -- 仍在等待偏移延时
              offset_count <= offset_count + 1;
              load_1       <= '1';
              state        <= on_search;
            end if;
          end if;

        -- ================================================================
        -- EN_SEARCH: 上传使能状态
        -- ================================================================
        when en_search =>
          if shift_done = '1' then
            rst_detecor  <= '0';
            load_2       <= '1';
            state        <= free;
            offset_count <= 0;
          else
            rst_detecor <= '1';
            if offset_count >= offset then
              offset_count <= offset_count + 1;
              load_2       <= '0';    -- 使能移位
              state        <= en_search;
            elsif offset_count = 60001 then
              offset_count <= offset + 1;
              state        <= en_search;
            else
              offset_count <= offset_count + 1;
              load_2       <= '1';
              state        <= en_search;
            end if;
          end if;

        -- ================================================================
        -- CHARGE: 充电/过流测试进行中
        -- ================================================================
        when charge =>
          if posedge = '1' then
            -- 充电脉冲结束（检测到RXD上升沿）
            rst_detecor <= '1';
            load_3      <= '0';       -- 准备移位输出过流状态
            en_charge   <= '0';       -- 关闭故障检测
            state       <= charge_search;
          else
            -- 充电仍在进行中
            rst_detecor <= '1';
            load_3      <= '1';       -- 保持（暂不移位）
            en_charge   <= '1';       -- 故障检测使能
            state       <= charge;
          end if;

        -- ================================================================
        -- CHARGE_SEARCH: 充电后上传过流状态
        -- ================================================================
        when charge_search =>
          if shift_done = '1' then
            load_3       <= '0';
            state        <= free;
            offset_count <= 0;
          else
            rst_detecor <= '1';
            if offset_count >= offset then
              offset_count <= offset_count + 1;
              load_3       <= '0';    -- 使能移位
              state        <= charge_search;
            elsif offset_count = 60001 then
              offset_count <= offset + 1;
              state        <= charge_search;
            else
              offset_count <= offset_count + 1;
              load_3       <= '1';
              state        <= charge_search;
            end if;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;
