LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY LM75B_DRV1 IS
PORT(clk_1M,SDA_IN,CLR:IN STD_LOGIC;
     ADDR1:IN STD_LOGIC_VECTOR(2 DOWNTO 0);
     TEM1:OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
     SCL,SDA,DIR,LK_O:OUT STD_LOGIC) ;
END LM75B_DRV1;

ARCHITECTURE behave OF LM75B_DRV1 IS
SIGNAL q:STD_LOGIC_VECTOR(5 DOWNTO 0);
SIGNAL ClK_500k1,CLK_500k2:STD_LOGIC;
SIGNAL SEL,SEL2:INTEGER RANGE 0 TO 1;
SIGNAL  ADDR,ADDR4,ADDR_TMP: STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL  TEMP: STD_LOGIC_VECTOR(8 DOWNTO 0);
 BEGIN
    
    
    PROCESS(clk_1M)
    BEGIN
        IF(rising_edge(clk_1M)) THEN
            ClK_500k1<=NOT CLK_500k2;
        END IF;
        IF(FALLing_edge(clk_1M)) THEN  --500k2 is later than 500k1,500k1 is used to countor 
            ClK_500k2<=CLK_500k1;
        END IF;
     END PROCESS;
     
     
     
    PROCESS(ClK_500k1,CLR) 
    BEGIN
      IF(CLR='0') THEN q<="000000";
      ELSE
        IF(rising_edge(ClK_500k1)) THEN  --2us*66=132us  refresh frequency 3.8kHz
           IF(CLR='1') THEN
             IF(q<55) THEN  --  
             q<=q+1;
             END IF;
           ELSE
             q<="000000";
           END IF;
        END IF;
       END IF;
     END PROCESS;
     
      
       PROCESS(ClK_500k1) -- to generate SCL
       BEGIN
        IF(falling_edge(ClK_500k1)) THEN
            IF(q>1 AND q<40) THEN  --  119?
             SCL<=q(0);
            ELSE
             SCL<='1';
             END IF;
        END IF;
       END PROCESS;
   
   
       PROCESS(ClK_500k2) -- to generate SCL  AND SDA_MASTER
       BEGIN
        IF(RISing_edge(ClK_500k2)) THEN
           IF(q="000000") THEN SDA<='1';
            ADDR<=ADDR1;      
           ELSIF(q=1 OR q=2) THEN SDA<='0';
           ELSIF(q=3 OR q=4) THEN SDA<='1';
           ELSIF(q=5 OR q=6) THEN SDA<='0';
           ELSIF(q=7 OR q=8) THEN SDA<='0';
           ELSIF(q=9 OR q=10) THEN SDA<='1';
           ELSIF(q=11 OR q=12) THEN SDA<=ADDR(2);
           ELSIF(q=13 OR q=14) THEN SDA<=ADDR(1);
           ELSIF(q=15 OR q=16) THEN SDA<=ADDR(0);
           ELSIF(q=17 OR q=18) THEN  
                IF(SEL=1) THEN SDA<='0'; ELSE SDA<='1';END IF;-- read mode
           ELSIF(q=19 OR q=20) THEN SDA<='0';-- ack bit  dir should be 0
           
           ELSIF(q=21 OR q=22) THEN SDA<='0';  --the later 8 bits are pointer data for reset pointer  the dir should be 1
           ELSIF(q=23 OR q=24) THEN SDA<='0'; 
           ELSIF(q=25 OR q=26) THEN SDA<='0';
           ELSIF(q=27 OR q=28) THEN SDA<='0';
           ELSIF(q=29 OR q=30) THEN SDA<='0';
           ELSIF(q=31 OR q=32) THEN SDA<='0';
           ELSIF(q=33 OR q=34) THEN SDA<='0';
           ELSIF(q=35 OR q=36) THEN SDA<='0'; 

           ELSIF(q=37 OR q=38) THEN SDA<='1'; -- ack bit  dir should be 1

           ELSIF(q=39 OR q=40) THEN SDA<='0';-- STOP bit  dir should be 1
           ELSIF(q=41 OR q=42) THEN SDA<='1';-- STOP bit  dir should be 1
           ELSE  SDA<='1';--  dir should be 0 
           END IF;
        
           IF(q>="0000000" AND q<=18) THEN DIR<='1';
           ELSIF(q>18 AND q<37) THEN 
                IF(SEL=1) THEN DIR<='1';
                ELSE DIR<='0';
                END IF;
           ELSIF(q>=37 AND q<45  ) THEN DIR<='1';
           ELSE DIR<='0';
           END IF;            
        END IF;
       END PROCESS;
   
     
       PROCESS(ClK_500k1) -- to Lock the data in
       BEGIN
        IF(falling_edge(ClK_500k1)) THEN
           IF(q=21 ) THEN TEMP(8)<=SDA_IN;
           ELSIF(q=23) THEN TEMP(7)<=SDA_IN;
           ELSIF(q=25) THEN TEMP(6)<=SDA_IN;
           ELSIF(q=27) THEN TEMP(5)<=SDA_IN;
           ELSIF(q=29) THEN TEMP(4)<=SDA_IN;
           ELSIF(q=31) THEN TEMP(3)<=SDA_IN;
           ELSIF(q=33) THEN TEMP(2)<=SDA_IN;
           ELSIF(q=35) THEN TEMP(1)<=SDA_IN;
           ELSIF(q=39) THEN TEMP(0)<='0';--SDA_IN
        
           ELSIF(q=45) THEN 
                SEL2<=SEL;
                IF(SEL=0) THEN
                   TEM1<=TEMP;
                END IF;
           ELSIF(q=47) THEN 
                SEL<=SEL2+1;
           END IF;
        END IF;
       END PROCESS; 
    
       PROCESS(ClK_500k1) -- to generate SCL
       BEGIN
        IF(falling_edge(ClK_500k1)) THEN
            IF(q=50 OR q=51 ) THEN  --  
             LK_O<='1';
            ELSE
             LK_O<='0';
             END IF;
        END IF;
       END PROCESS;
    
    

END behave;