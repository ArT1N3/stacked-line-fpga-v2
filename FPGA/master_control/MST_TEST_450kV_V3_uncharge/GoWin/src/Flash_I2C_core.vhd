--=============================================================================
-- flash_i2c_core - I2C Flash核心控制器（100kHz I2C，读写操作）
--   start上升沿锁存ADDR/DAT_in/RD_WR_n，自动完成I2C读写时序
--   add1计数器在clk_I2C下0→85循环，各阶段输出SCL/SDA
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity flash_i2c_core is
  port(clk_1m,rd_wr_n,sda_in,start:in std_logic; addr,dat_in:in std_logic_vector(7 downto 0);
       scl,sda_out,dir:out std_logic; ok:out std_logic; dat_r:out std_logic_vector(7 downto 0));
end entity flash_i2c_core;
architecture bev of flash_i2c_core is
  signal add,add1:unsigned(6 downto 0):=(others=>'0'); signal clk_i2c,delay,delay1,delay2,r_w_n,ok1:std_logic;
  signal address,dat_i,addr_out,ctr,dat_out:std_logic_vector(7 downto 0);
begin
  -- start上升沿锁存输入参数
  process(start)begin if rising_edge(start) then address<=addr;dat_i<=dat_in;r_w_n<=rd_wr_n; end if; end process;
  -- I2C时钟生成（1MHz/31→~32kHz→半周期≈15.6us，占空比10/31≈32%）
  process(clk_1m)begin if rising_edge(clk_1m) then if add<30 then add<=add+1; else add<=(others=>'0'); end if; if add<10 then clk_i2c<='0'; else clk_i2c<='1'; end if; end if; end process;
  -- DDR延时链（clk_i2c→delay→delay1）
  process(clk_1m)begin if falling_edge(clk_1m) then delay<=clk_i2c; end if; end process;
  process(clk_1m)begin if rising_edge(clk_1m) then delay1<=delay; end if; end process;
  -- delay2组合逻辑（add=18-19时有效）
  process(add)begin if add>=18 and add<20 then delay2<='1'; else delay2<='0'; end if; end process;
  -- I2C阶段计数器（clk_I2C域，0→85循环）
  process(clk_i2c,start)begin if start='0' then add1<=(others=>'0'); elsif rising_edge(clk_i2c) then if add1<85 then add1<=add1+1; end if; end if; end process;
  -- OK信号生成
  process(add1,start,clk_i2c)begin if start='0' then ok<='0';ok1<='0'; elsif falling_edge(clk_i2c) then if add1>=85 then ok<='1';else ok<='0';end if;if add1>=84 then ok1<='1';else ok1<='0';end if;end if;end process;
  -- SCL生成（DDR在delay1上升沿）
  process(delay1,start)
  begin
    if start='0' then scl<='0';
    elsif rising_edge(delay1) then
      if add1>=1 and add1<=3 then scl<='1'; -- 起始条件
      else
        if r_w_n='1' then -- 读操作
          if add1>=42 and add1<=43 then scl<='1'; elsif add1>3 and add1<82 then scl<=add1(0); elsif add1<85 then scl<='1'; else scl<='0'; end if;
        else -- 写操作
          if add1>3 and add1<59 then scl<=add1(0); elsif add1<61 then scl<='1'; else scl<='0'; end if;
        end if;
      end if;
    end if;
  end process;
  -- SDA输出+方向控制（DDR在delay2上升沿）
  process(add1,delay2,start)
    variable sda_v:std_logic;
  begin
    if start='0' then sda_out<='1';
    elsif rising_edge(delay2) then
      -- dir控制
      if(add1>=20 and add1<=21)or(add1>=38 and add1<=39) then dir<='0';
      else if r_w_n='1' then if(add1>=60 and add1<=61)or(add1>=62 and add1<=79) then dir<='0'; else dir<='1'; end if;
           else if add1>=56 and add1<=57 then dir<='0'; else dir<='1'; end if; end if;
      end if;
      -- SDA数据序列
      sda_v:='1';
      if add1<=1 then sda_v:='1'; -- 起始
      elsif add1<=3 then sda_v:='0';
      elsif add1<=5 then sda_v:='1'; -- 器件地址=1010000
      elsif add1<=7 then sda_v:='0'; elsif add1<=9 then sda_v:='1'; elsif add1<=11 then sda_v:='0';
      elsif add1<=13 then sda_v:='0'; elsif add1<=15 then sda_v:='0'; elsif add1<=17 then sda_v:='0'; elsif add1<=19 then sda_v:='0';
      elsif add1<=21 then sda_v:='1'; -- ACK
      elsif add1<=23 then sda_v:=address(7); elsif add1<=25 then sda_v:=address(6);
      elsif add1<=27 then sda_v:=address(5); elsif add1<=29 then sda_v:=address(4);
      elsif add1<=31 then sda_v:=address(3); elsif add1<=33 then sda_v:=address(2);
      elsif add1<=35 then sda_v:=address(1); elsif add1<=37 then sda_v:=address(0);
      elsif add1<=39 then sda_v:='1'; -- ACK
      else
        if r_w_n='0' then -- 写: 发送8位数据
          if add1<=41 then sda_v:=dat_i(7); elsif add1<=43 then sda_v:=dat_i(6); elsif add1<=45 then sda_v:=dat_i(5);
          elsif add1<=47 then sda_v:=dat_i(4); elsif add1<=49 then sda_v:=dat_i(3); elsif add1<=51 then sda_v:=dat_i(2);
          elsif add1<=53 then sda_v:=dat_i(1); elsif add1<=55 then sda_v:=dat_i(0);
          elsif add1<=57 then sda_v:='1'; -- ACK
          elsif add1<=59 then sda_v:='0'; -- 停止
          else sda_v:='1';
          end if;
        else -- 读: 发送器件地址后接收数据
          if add1<=41 then sda_v:='1'; elsif add1<=43 then sda_v:='0'; elsif add1<=45 then sda_v:='1';
          elsif add1<=47 then sda_v:='0'; elsif add1<=49 then sda_v:='1'; elsif add1<=51 then sda_v:='0';
          elsif add1<=53 then sda_v:='0'; elsif add1<=55 then sda_v:='0'; elsif add1<=57 then sda_v:='0';
          elsif add1<=59 then sda_v:='1'; elsif add1<=79 then sda_v:='1';
          elsif add1<=81 then sda_v:='0'; -- 停止
          else sda_v:='1';
          end if;
        end if;
      end if;
      sda_out<=sda_v;
    end if;
    -- 读数据采集（SDA_in→dat_out，在delay2上升沿时add1已稳定）
    if rising_edge(delay2) then
      case add1 is
        when"0111110"|"0111111"=>dat_out(7)<=sda_in;when"1000000"|"1000001"=>dat_out(6)<=sda_in;
        when"1000010"|"1000011"=>dat_out(5)<=sda_in;when"1000100"|"1000101"=>dat_out(4)<=sda_in;
        when"1000110"|"1000111"=>dat_out(3)<=sda_in;when"1001000"|"1001001"=>dat_out(2)<=sda_in;
        when"1001010"|"1001011"=>dat_out(1)<=sda_in;when"1001100"|"1001101"=>dat_out(0)<=sda_in;
        when others=>null;
      end case;
    end if;
  end process;
  -- 读取数据输出锁存
  process(ok1,r_w_n)begin if r_w_n='0' then dat_r<=(others=>'0'); elsif rising_edge(ok1) then dat_r<=dat_out; end if; end process;
end bev;
