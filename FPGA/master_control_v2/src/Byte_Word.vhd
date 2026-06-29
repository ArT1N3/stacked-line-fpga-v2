--=============================================================================
-- byte_word - 16位字拼接器（Byte_H,Byte_L → Word[15:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity byte_word is port(byte_h,byte_l:in std_logic_vector(7 downto 0); word:out std_logic_vector(15 downto 0)); end entity byte_word;
architecture rtl of byte_word is begin word<=byte_h & byte_l; end architecture rtl;
