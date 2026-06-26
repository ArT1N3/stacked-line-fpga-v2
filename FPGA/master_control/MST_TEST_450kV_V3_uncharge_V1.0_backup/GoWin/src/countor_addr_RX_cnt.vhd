LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY countor_addr_RX_cnt IS
PORT(clk,clk2,EN:IN STD_LOGIC;
	 qout:OUT STD_LOGIC_VECTOR(4 DOWNTO 0);--OUT STD_LOGIC
	 co:OUT STD_LOGIC) ;
END countor_addr_RX_cnt;

ARCHITECTURE behave OF countor_addr_RX_cnt IS
SIGNAL q:STD_LOGIC_VECTOR(4 DOWNTO 0);
 BEGIN
    
	PROCESS(clk,EN)
	BEGIN
	IF(EN='0') THEN q<="00000";
	ELSE 
			IF(rising_edge(clk)) THEN
					IF(q<22) THEN --22 Bytes
					 q<=q+1;
					ELSE
					 q<="00000";
					END IF;
					

			END IF;
	 END IF;
	 END PROCESS;
	 
	PROCESS(EN,clk2)
	BEGIN
	IF(EN='0') THEN co<='0';
	ELSE 
		IF(rising_edge(clk2)) THEN
			IF(q>=22) THEN co<='1';  --22
			ELSE co<='0';
			END IF;
		END IF;
	END IF;
	END PROCESS;
	
	
	

	qout<=q;  
END behave;