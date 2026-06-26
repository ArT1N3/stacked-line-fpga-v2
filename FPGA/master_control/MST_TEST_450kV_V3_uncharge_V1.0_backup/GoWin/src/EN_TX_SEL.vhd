--=============================================================================
-- en_tx_sel - TX输出选择器（根据Grp[7:0]控制TX1/TX2使能，输出取反）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity en_tx_sel is port(clk,tx:in std_logic; grp:in std_logic_vector(7 downto 0); tx1,tx2:out std_logic); end entity en_tx_sel;
architecture rtl of en_tx_sel is signal tx1_en,tx2_en:std_logic;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if grp="00000000" then tx1_en<='1';tx2_en<='1';
      elsif grp="00000001" then tx1_en<='1';tx2_en<='0';
      elsif grp="00000010" then tx1_en<='0';tx2_en<='1';
      else tx1_en<='0';tx2_en<='0'; end if;
    end if;
  end process;
  tx1<=not(tx or(not tx1_en)); tx2<=not(tx or(not tx2_en));
end architecture rtl;
