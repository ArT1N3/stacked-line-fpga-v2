--=============================================================================
-- multi_signal - 多路信号时序发生器（脉冲突发、触发、延时控制）
--=============================================================================
-- 功能：根据LOCK锁存的T_CH/T_MS/T_EXP0/T_EXP01/T_EXP2/T_EXP3参数，
--   计算各触发时间点，在clk_20ns计数器上生成TRIG_MS/TRIG_EXP1-3/TRIG_CHK/M_pulse/Chk2
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity multi_signal is
  port(clk_20ns,clr,trig,lock:in std_logic;
       t_ch,t_ms,t_exp0,t_exp01:in std_logic_vector(15 downto 0);
       t_exp2,t_exp3:in std_logic_vector(23 downto 0);
       trig_ms,trig_exp1,trig_exp2,trig_exp3,trig_chk:out std_logic;
       t_dly,dly1_h,dly1_l:out std_logic_vector(15 downto 0);
       m_pulse,chk2:out std_logic);
end entity multi_signal;

architecture rtl of multi_signal is
  signal q1:unsigned(23 downto 0):=(others=>'0');
  signal t_bs,tms,texp1,texp2,texp3:unsigned(23 downto 0);
  signal t1,t2,t3,t4:unsigned(15 downto 0);
  signal t11,t22,t33:unsigned(23 downto 0);
  signal tmp1,tmp2,tmp3,tmp4:unsigned(23 downto 0);
  signal tmp1x,tmp2x,tmp3x,tmp4x,t_exp1:unsigned(23 downto 0);
  signal tmp11,tmp22,tmp33,tmp44:unsigned(23 downto 0);
  signal tmp11x:unsigned(23 downto 0);
  signal t_chg,t_m,tch:unsigned(15 downto 0);
  signal ts,ts2,m_pls:unsigned(23 downto 0);
begin
  tch<=t_chg+3;
  -- 时序计算：tch*100 = (tch*4)+(tch*32)+(tch*64)
  tmp1<=(23 downto 18=>'0')&tch&"00";        -- *4
  tmp2<=(23 downto 21=>'0')&tch&"00000";     -- *32
  tmp3<=(23 downto 22=>'0')&tch&"000000";    -- *64
  tmp4<=tmp1+tmp2+tmp3;                       -- *100
  -- T_EXP1拼接
  t_exp1<=unsigned(t_exp0(7 downto 0)&t_exp01);
  -- *50 = *2 + *16 + *32
  tmp1x<=tmp4(22 downto 0)&'0';              -- *2
  tmp2x<=tmp4(19 downto 0)&"0000"; -- *16
  tmp3x<=tmp4(18 downto 0)&"00000"; -- *32
  tmp4x<=tmp1x+tmp2x+tmp3x;                   -- *50
  t_bs<=tmp4x;                                -- 基准时间 = tch*5000
  -- T_M*100 = (T_M*4)+(T_M*32)+(T_M*64)
  tmp11<=(23 downto 18=>'0')&t_m&"00";
  tmp22<=(23 downto 21=>'0')&t_m&"00000";
  tmp33<=(23 downto 22=>'0')&t_m&"000000";
  tmp44<=tmp11+tmp22+tmp33;
  -- *500 = *100*5 = *100*4 + *100
  tmp11x<=tmp44(21 downto 0)&"00";            -- *4
  ts<=tmp11x+tmp44;                            -- *5 → *500
  ts2<=t_bs+ts;                                -- 总计时基准
  -- T_EXP偏移量（*0.5 = /2）
  t11<=t_exp1(22 downto 1)&"00";
  t22<=unsigned(t_exp2(22 downto 1)&"00");
  t33<=unsigned(t_exp3(22 downto 1)&"00");
  t_dly<=std_logic_vector(t_m);
  -- LOCK上升沿锁存输入参数
  process(lock)
  begin
    if rising_edge(lock) then t_chg<=unsigned(t_ch); t_m<=unsigned(t_ms); dly1_h<=t_exp0; dly1_l<=t_exp01; end if;
  end process;
  -- LOCK下降沿计算触发时间点
  process(lock)
  begin
    if falling_edge(lock) then
      tms<=ts2;
      if ts2>200000 then m_pls<=ts2-200000; else m_pls<=to_unsigned(2,24); end if; -- 4ms偏移
      if t_exp1(23)='0' then texp1<=ts2+t11; elsif ts2>t11 then texp1<=ts2-t11; else texp1<=(others=>'0'); end if;
      if t_exp2(23)='0' then texp2<=ts2+t22; elsif ts2>t22 then texp2<=ts2-t22; else texp2<=(others=>'0'); end if;
      if t_exp3(23)='0' then texp3<=ts2+t33; elsif ts2>t33 then texp3<=ts2-t33; else texp3<=(others=>'0'); end if;
    end if;
  end process;
  -- 主计数器与触发输出
  process(clk_20ns,trig,clr)
  begin
    if rising_edge(clk_20ns) then
      if clr='1' then q1<=to_unsigned(16400000-3999,24); -- ~328ms
      elsif trig='1' then q1<=(others=>'0');
      else if q1<16400000 then q1<=q1+1; end if; end if;
      -- M_pulse: 约5ms脉冲窗口
      if q1>m_pls and q1<m_pls+256000 then m_pulse<='1'; else m_pulse<='0'; end if;
      -- TRIG_CHK: TMS前20us
      if q1+500>=tms and q1+475<tms and tms>100 then trig_chk<='1'; else trig_chk<='0'; end if;
      -- Chk2: TMS后500us
      if q1>=tms+25000 and q1<tms+25025 then chk2<='1'; else chk2<='0'; end if;
      -- TRIG_MS: TMS处约0.3us脉冲
      if q1>=tms and q1<tms+8 and tms>100 then trig_ms<='1'; else trig_ms<='0'; end if;
      -- TRIG_EXP1-3: 各偏移处约0.3us脉冲
      if q1>=texp1 and q1<texp1+8 and texp1>100 then trig_exp1<='1'; else trig_exp1<='0'; end if;
      if q1>=texp2 and q1<texp2+8 and texp2>100 then trig_exp2<='1'; else trig_exp2<='0'; end if;
      if q1>=texp3 and q1<texp3+8 and texp3>100 then trig_exp3<='1'; else trig_exp3<='0'; end if;
    end if;
  end process;
end architecture rtl;
