LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY dat_store_RX IS
PORT(dat:IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	 addr:IN STD_LOGIC_VECTOR(4 downto 0);
	 lock_in:IN STD_LOGIC;
	 Lock_out,RST:IN STD_LOGIC;
	 HEAD:OUT STD_LOGIC_VECTOR(7 downto 0);
	 CMD:OUT STD_LOGIC_VECTOR(7 downto 0);
	 Grp:OUT STD_LOGIC_VECTOR(7 downto 0);
	 Aux:OUT STD_LOGIC_VECTOR(7 downto 0);	
	 dat1:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat3:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat5:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat7:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat9:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat11:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat13:OUT STD_LOGIC_VECTOR(15 downto 0);
	 dat15:OUT STD_LOGIC_VECTOR(7 downto 0);
	 CHK:OUT STD_LOGIC_VECTOR(15 downto 0);
	 END2:OUT STD_LOGIC_VECTOR(7 downto 0));
END dat_store_RX;

ARCHITECTURE behave OF dat_store_RX IS
SIGNAL HEAD1,CMD1,Grp1,END1,AUX1,RSV1,daX:STD_LOGIC_VECTOR(7 downto 0);
SIGNAL da1,da3,da5,da7,da9,da11,da13,CK1:STD_LOGIC_VECTOR(15 downto 0);
SIGNAL da15:STD_LOGIC_VECTOR(7 downto 0);
 BEGIN
    
PROCESS(Lock_out,RST)
BEGIN
 IF(RST='0') THEN  
  HEAD<="00000000";CMD<="00000000";Grp<="00000000";Aux<="00000000";
  dat1<="0000000000000000";  dat3<="0000000000000000";dat5<="0000000000000000";
  dat7<="0000000000000000"; dat9<="0000000000000000";dat11<="0000000000000000";
  dat13<="0000000000000000";dat15<="00000000";
  CHK<="0000000000000000";
  END2<="00000000";
 ELSE
  IF(rising_edge(Lock_out))  THEN
  HEAD<= HEAD1;CMD<=CMD1;Grp<=Grp1;Aux<=Aux1;dat1<=da1;dat3<=da3;dat5<=da5;dat7<=da7;dat9<=da9;
  dat11<=da11;dat13<=da13;dat15<=da15;
  CHK<=CK1;END2<=END1;
  END IF;
 END IF;
END PROCESS;

  


PROCESS(Lock_in)
BEGIN
  IF(rising_edge(Lock_in))  THEN
     IF(addr="00001") THEN HEAD1<=dat;    --1
     ELSIF(addr="00010") THEN  CMD1<=dat;--2
	 ELSIF(addr="00011") THEN  Grp1<=dat;--3
	 ELSIF(addr="00100") THEN  Aux1<=dat;--4
     ELSIF(addr="00101") THEN  da1(15 DOWNTO 8)<=dat;--5
	 ELSIF(addr="00110") THEN  da1(7 DOWNTO 0)<=dat;--6
	 ELSIF(addr="00111") THEN  da3(15 DOWNTO 8)<=dat;--7
     ELSIF(addr="01000") THEN  da3(7 DOWNTO 0)<=dat; --8
	 ELSIF(addr="01001") THEN  da5(15 DOWNTO 8)<=dat;--9
	 ELSIF(addr="01010") THEN  da5(7 DOWNTO 0)<=dat;--10
     ELSIF(addr="01011") THEN  da7(15 DOWNTO 8)<=dat;--11
	 ELSIF(addr="01100") THEN  da7(7 DOWNTO 0)<=dat;--12
	 ELSIF(addr="01101") THEN  da9(15 DOWNTO 8)<=dat;--13
     ELSIF(addr="01110") THEN  da9(7 DOWNTO 0)<=dat;--14
	 ELSIF(addr="01111") THEN  da11(15 DOWNTO 8)<=dat;--15
     ELSIF(addr="10000") THEN  da11(7 DOWNTO 0)<=dat;--16
	 ELSIF(addr="10001") THEN  da13(15 DOWNTO 8)<=dat;--17
	 ELSIF(addr="10010") THEN  da13(7 DOWNTO 0)<=dat;--18
     ELSIF(addr="10011") THEN  da15(7 DOWNTO 0)<=dat;--19
	 ELSIF(addr="10100") THEN  CK1(15 DOWNTO 8)<=dat;--20
	 ELSIF(addr="10101") THEN  CK1(7 DOWNTO 0)<=dat;--21
	 ELSIF(addr="10110") THEN  END1(7 DOWNTO 0)<=dat;--22
	 ELSE   daX<=dat;
    END IF;
  END IF;
END PROCESS;



	 

END behave;