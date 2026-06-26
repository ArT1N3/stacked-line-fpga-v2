--=============================================================================
-- err_shift_test - 10位并行加载移位寄存器
--=============================================================================
-- 功能：
--   根据ERR_ctrl的指令加载并行状态数据（在线/使能/故障），
--   然后通过TXD串行移位输出（低位先出）上传给主控。
--   在每次10位上传之间插入1us的字节间隔。
--
-- LOAD信号编码（来自ERR_ctrl的3位总线）：
--   "011"（load_1=0）→ 加载在线（供电故障）状态
--   "101"（load_2=0）→ 加载使能状态（取反：线路上低有效）
--   "110"（load_3=0）→ 加载过流故障状态
--   "111"（全高）    → 空闲（保持并行数据，不操作）
--   其他值为无效/忽略
--
-- 移位时序：
--   系统时钟：50MHz（20ns周期）
--   移位时钟：10us周期（500个系统时钟）
--     - 每位移位输出耗时10us
--     - 10位 × 10us = 每上传帧100us
--
-- 帧间间隔（out_sel / mux21a）：
--   输出经过一个由out_sel控制的2选1选择器（mux21a）：
--     out_sel='0' → 移位数据（err_out）送往TXD
--     out_sel='1' → VCC（空闲高电平）送往TXD
--   在每个10us位周期内：
--     前1us:  out_sel='1'（空闲间隔）
--     中8us:  out_sel='0'（移位数据有效）
--     后1us:  out_sel='1'（空闲间隔）
--   这创建了RS-232兼容的帧格式，具有保证的位间间隔。
--
-- 状态机：
--   free      → 空闲，等待加载指令
--     ↓ load_state = "011"/"101"/"110"
--   load      → 并行加载数据到移位寄存器
--     ↓（下一个时钟）
--   send      → 串行移位输出10位（100us）
--     ↓ cnt = 9 且 shift_counter = 498（最后一位完成）
--   send_done → 等待load_state返回"111"
--     ↓ load_state = "111"
--   free      → 准备好下一次指令
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_shift_test is
  port (
    clk         : in  std_logic;    -- 50MHz系统时钟
    rst         : in  std_logic;    -- 异步复位（低有效）
    err_total   : in  std_logic_vector(10 downto 1); -- 过流故障（正常=1, 故障=0）
    err_charge  : in  std_logic_vector(10 downto 1); -- 供电故障（正常=0, 故障=1）
    en_state    : in  std_logic_vector(10 downto 1); -- 使能状态
    load_1      : in  std_logic;    -- 加载在线状态指令
    load_2      : in  std_logic;    -- 加载使能状态指令
    load_3      : in  std_logic;    -- 加载过流状态指令
    err_out     : out std_logic;    -- 串行输出（低位先出，位1→位10）
    out_sel     : out std_logic;    -- 选择器控制: '0'=数据, '1'=VCC空闲
    shift_done  : out std_logic     -- 10位全部移位输出完成
  );
end entity err_shift_test;

architecture rtl of err_shift_test is

  -- 状态机
  type work_state is (free, load, send, send_done);
  signal state : work_state;

  -- shift_en: 每10us产生1个周期的高脉冲（移位时钟）
  -- shift_counter: 0-499，从50MHz产生10us周期
  signal shift_en      : std_logic;
  signal shift_counter : integer range 0 to 499;

  -- q: 10位移位寄存器（位1=LSB=第一个移出）
  signal q             : std_logic_vector(10 downto 1);

  -- cnt: 已移出的位数（0-9）
  signal cnt           : integer range 0 to 9;

  -- load_state: 拼接的load信号，便于解码
  signal load_state    : std_logic_vector(2 downto 0);

  -- 缓冲的shift_done输出
  signal shift_done_buf : std_logic;

  -- interval_sel: 控制帧间间隔时序
  signal interval_sel  : std_logic;

begin

  -- 拼接load信号用于模式匹配
  -- load_state(2)=load_1, load_state(1)=load_2, load_state(0)=load_3
  load_state <= load_1 & load_2 & load_3;
  shift_done <= shift_done_buf;

  -- ========================================================================
  -- 10us移位时钟发生器
  -- 50MHz下500个周期 = 每位10us周期
  -- shift_en在每个周期结束时恰好保持1个时钟周期的高电平。
  -- 仅在state=send（移位进行中）时运行。
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      shift_en      <= '0';
      shift_counter <= 0;
    elsif rising_edge(clk) then
      if state = send then
        if shift_counter = 0 then
          shift_en      <= '0';
          shift_counter <= shift_counter + 1;
        elsif shift_counter = 499 then
          shift_counter <= 0;       -- 回绕到下一个10us周期的开始
          shift_en      <= '1';     -- 脉冲：移出一位
        else
          shift_counter <= shift_counter + 1;
          shift_en      <= '0';
        end if;
      else
        -- 非send状态：复位计数器
        shift_en      <= '0';
        shift_counter <= 0;
      end if;
    end if;
  end process;

  -- ========================================================================
  -- 主状态机：加载 → 移位 → 完成 → 空闲
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      q              <= (others => '1');   -- 空闲：所有位为高（mark）
      shift_done_buf <= '0';
      cnt            <= 0;
      state          <= free;
    elsif rising_edge(clk) then
      case state is

        -- ----------------------------------------------------------------
        -- FREE: 等待有效的加载指令
        -- 有效指令恰好有一个load信号为低（单热编码）：
        --   "011" → load_1有效 → 在线状态
        --   "101" → load_2有效 → 使能状态
        --   "110" → load_3有效 → 过流状态
        -- ----------------------------------------------------------------
        when free =>
          if load_state = "011" or load_state = "101" or load_state = "110" then
            shift_done_buf <= '0';    -- 清除之前的完成标志
            state          <= load;
          else
            state          <= free;
            shift_done_buf <= '0';
            q              <= (others => '1');  -- 空闲：全高
          end if;

        -- ----------------------------------------------------------------
        -- LOAD: 将选中的状态并行加载到移位寄存器
        -- "011" → 供电故障（在线状态）：正常=0, 故障=1
        -- "101" → 使能状态，取反（输出低有效）
        -- "110" → 过流故障：正常=1, 故障=0
        -- ----------------------------------------------------------------
        when load =>
          if load_state = "011" then
            -- 在线状态：每通道供电故障
            q <= err_charge;
            state <= send;
          elsif load_state = "101" then
            -- 使能状态：取反（主控期望低有效）
            q <= not en_state;
            state <= send;
          elsif load_state = "110" then
            -- 过流故障状态
            q <= err_total;
            state <= send;
          else
            -- 无效：返回free
            state <= free;
            q     <= (others => '1');
          end if;

        -- ----------------------------------------------------------------
        -- SEND: 串行移位输出10位，低位先出
        -- 每次shift_en脉冲（每10us）：
        --   q(9:1) <= q(10:2) → 右移1位，LSB输出到err_out
        --   cnt递增以跟踪已移出的位数
        -- 9次移位后（cnt=9），等待shift_counter=498然后完成。
        -- ----------------------------------------------------------------
        when send =>
          if cnt = 9 then
            -- 10位全部处理完，等待最后的shift_counter
            if shift_counter = 498 then
              shift_done_buf <= '1';   -- 信号：上传完成
              cnt            <= 0;
              state          <= send_done;
            else
              state <= send;           -- 等待最后一位周期结束
            end if;
          else
            if shift_en = '1' then
              -- 右移：位2→位1, 位3→位2, ..., 位10→位9
              -- LSB（位1）输出到err_out，MSB（位10）移入位9
              q(9 downto 1) <= q(10 downto 2);
              cnt           <= cnt + 1;
              state         <= send;
            end if;
          end if;

        -- ----------------------------------------------------------------
        -- SEND_DONE: 等待load信号返回"111"（全部空闲）
        -- 此握手确保ERR_ctrl知道上传已完成。
        -- ----------------------------------------------------------------
        when send_done =>
          if load_state = "111" then
            state <= free;             -- 握手完成
          else
            state <= send_done;        -- 等待ERR_ctrl取消load置位
          end if;

      end case;
    end if;
  end process;

  -- ========================================================================
  -- 串行输出：移位寄存器的LSB（位1）
  -- 送往mux21a的数据输入端（a），在out_sel='0'时被选中。
  -- ========================================================================
  err_out <= q(1);

  -- ========================================================================
  -- 帧间间隔时序（out_sel生成）
  -- 在每个10us位周期内（shift_counter 0→499）：
  --   0-48    （前1us）:  interval_sel='1' → 选择器选VCC（空闲高）
  --   49-448  （中8us）:  interval_sel='0' → 选择器选移位数据
  --   449-499 （后1us）:  interval_sel='1' → 选择器选VCC（空闲高）
  -- 非发送状态：interval_sel='1'（输出空闲高电平）
  -- ========================================================================
  process (clk, rst)
  begin
    if rst = '0' then
      interval_sel <= '1';          -- 空闲：输出高电平（VCC）
    elsif rising_edge(clk) then
      if state = send then
        if shift_counter = 0 then
          interval_sel <= '1';      -- 周期开始：1us空闲间隔
        elsif shift_counter = 49 then
          interval_sel <= '0';      -- 数据窗口：移位数据输出
        elsif shift_counter = 449 then
          interval_sel <= '1';      -- 周期结束：1us空闲间隔
        end if;
      else
        interval_sel <= '1';        -- 非发送：空闲高电平
      end if;
    end if;
  end process;

  out_sel <= interval_sel;

end architecture rtl;
