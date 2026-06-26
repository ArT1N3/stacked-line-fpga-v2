--=============================================================================
-- ad_mcp3202 - MCP3202 SPI ADC驱动（双通道12位，50.6kHz采样率）
--   SPI时序：add1计数器在CLK1(2MHz)下0→75循环
--   通道1: add1=2-36, 通道2: add1=37-72, add1=73时LK=1完成
--   比较器：AD值vs REF+阈值 → P_OV/N_OV/P_NF/N_NF/U_HIGH
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity ad_mcp3202 is
  port(clk_50m,trig:in std_logic; din:in std_logic; ref:in std_logic_vector(11 downto 0);
       ad_cs,ad_clk,ad_din,lk:out std_logic; ad_dat1,ad_dat2:out std_logic_vector(11 downto 0);
       p_ov,n_ov,p_nf,n_nf,u_high:out std_logic);
end entity ad_mcp3202;
architecture bev of ad_mcp3202 is
  signal add,add1:unsigned(7 downto 0):=(others=>'0'); signal clk1,clk2,clk_en,clk3:std_logic;
  signal ad_tmp1,ad_tmp2,cnst,cnst2:unsigned(11 downto 0);
begin
  cnst<=to_unsigned(250,12); cnst2<=to_unsigned(250,12); -- 250→500V阈值
  -- 50MHz/14→~3.57MHz基准，产生约2MHz的CLK1/CLK2
  process(clk_50m)begin if rising_edge(clk_50m) then if add<13 then add<=add+1; else add<=(others=>'0'); end if; end if; end process;
  process(add,clk_50m)begin
    if falling_edge(clk_50m) then if add<3 then clk1<='1'; else clk1<='0'; end if; if add>=7 and add<10 then clk2<='1'; else clk2<='0'; end if; end if;
  end process;
  -- ADC周期计数器（CLK1域，trig=1复位，0→75循环）
  process(clk1,trig)begin if trig='1' then add1<=(others=>'0'); elsif rising_edge(clk1) then if add1<=75 then add1<=add1+1; end if; end if; end process;
  -- SPI时序生成+数据采集（DDR）
  process(add1,clk1,clk2)
  begin
    if rising_edge(clk2) then
      -- AD_CLK生成（16个时钟脉冲）
      if(add1>=2 and add1<=36)or(add1>=39 and add1<=72) then ad_clk<=add1(0); else ad_clk<='0'; end if;
      -- AD_CS生成（低有效）
      if(add1>=2 and add1<36)or(add1>=37 and add1<72) then ad_cs<='0'; else ad_cs<='1'; end if;
    end if;
    if falling_edge(clk1) then
      -- AD_DIN指令（通道1:0xD(单端CH0), 通道2:0xF(单端CH1)）
      if add1=2 or add1=3 then ad_din<='1'; elsif add1=4 or add1=5 then ad_din<='1'; elsif add1=6 or add1=7 then ad_din<='0'; elsif add1=8 or add1=9 then ad_din<='1';
      elsif add1=38 or add1=39 then ad_din<='1'; elsif add1=40 or add1=41 then ad_din<='1'; elsif add1=42 or add1=43 then ad_din<='1'; elsif add1=44 or add1=45 then ad_din<='1';
      else ad_din<='0'; end if;
    end if;
    if rising_edge(clk2) then
      -- 通道1数据采集（add1=13-35，奇数值）
      case add1 is
        when "00001101"=>ad_tmp1(11)<=din;when"00001111"=>ad_tmp1(10)<=din;when"00010001"=>ad_tmp1(9)<=din;
        when"00010011"=>ad_tmp1(8)<=din;when"00010101"=>ad_tmp1(7)<=din;when"00010111"=>ad_tmp1(6)<=din;
        when"00011001"=>ad_tmp1(5)<=din;when"00011011"=>ad_tmp1(4)<=din;when"00011101"=>ad_tmp1(3)<=din;
        when"00011111"=>ad_tmp1(2)<=din;when"00100001"=>ad_tmp1(1)<=din;when"00100011"=>ad_tmp1(0)<=din;
        when"00100100"=>ad_dat1<=std_logic_vector(ad_tmp1); -- add1=36: 锁存通道1结果
        -- 通道2数据采集（add1=49-71）
        when"00110001"=>ad_tmp2(11)<=din;when"00110011"=>ad_tmp2(10)<=din;when"00110101"=>ad_tmp2(9)<=din;
        when"00110111"=>ad_tmp2(8)<=din;when"00111001"=>ad_tmp2(7)<=din;when"00111011"=>ad_tmp2(6)<=din;
        when"00111101"=>ad_tmp2(5)<=din;when"00111111"=>ad_tmp2(4)<=din;when"01000001"=>ad_tmp2(3)<=din;
        when"01000011"=>ad_tmp2(2)<=din;when"01000101"=>ad_tmp2(1)<=din;when"01000111"=>ad_tmp2(0)<=din;
        when"01001000"=>ad_dat2<=std_logic_vector(ad_tmp2); -- add1=72: 锁存通道2结果
        when others=>null;
      end case;
      -- LK锁存信号（add1=73）
      if add1=73 then lk<='1'; else lk<='0'; end if;
      -- 比较器结果（add1=74）
      if add1=74 then
        if ad_tmp1>unsigned(ref)+cnst then p_ov<='1';p_nf<='0'; elsif ad_tmp1+cnst<unsigned(ref) then p_ov<='0';p_nf<='1'; else p_ov<='0';p_nf<='0'; end if;
        if ad_tmp2>unsigned(ref)+cnst then n_ov<='1';n_nf<='0'; elsif ad_tmp2+cnst<unsigned(ref) then n_ov<='0';n_nf<='1'; else n_ov<='0';n_nf<='0'; end if;
        if ad_tmp1>cnst2 or ad_tmp2>cnst2 then u_high<='1'; else u_high<='0'; end if;
      end if;
    end if;
  end process;
end bev;
