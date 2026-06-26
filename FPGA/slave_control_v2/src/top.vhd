--=============================================================================
-- top - V2.0 分控板 FPGA 顶层 (GW1N-UV9QN88C6/I5, QFN88)
--=============================================================================
-- V1.0 兼容端口名映射到 V2.0 core
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    -- 系统（与V1.0相同）
    clk         : in  std_logic;   -- 50MHz，pin 11
    rst         : in  std_logic;   -- 复位，pin 82

    -- 光纤接口（V1.0复用RXD/TXD引脚名）
    RXD         : in  std_logic;   -- 光纤RX输入，pin 26
    TXD         : out std_logic;   -- 光纤TX输出，pin 25

    -- 地址（V2.0扩展为8位）
    address     : in  std_logic_vector(7 downto 0);

    -- 模块接口（V2.0缩减为4通道）
    short_in    : in  std_logic_vector(3 downto 0);
    relay_out   : out std_logic_vector(3 downto 0);

    -- LED
    fault_led   : out std_logic_vector(3 downto 0);
    status_led  : out std_logic
  );
end entity top;

architecture rtl of top is
  component slave_ctrl_v2 is
    port (
      clk_50M     : in  std_logic;
      rst_n       : in  std_logic;
      fiber_rx    : in  std_logic;
      fiber_tx    : out std_logic;
      address     : in  std_logic_vector(7 downto 0);
      short_in    : in  std_logic_vector(3 downto 0);
      relay_out   : out std_logic_vector(3 downto 0);
      fault_led   : out std_logic_vector(3 downto 0);
      status_led  : out std_logic
    );
  end component;
begin
  u_slave : slave_ctrl_v2
    port map (
      clk_50M    => clk,
      rst_n      => rst,
      fiber_rx   => RXD,
      fiber_tx   => TXD,
      address    => address,
      short_in   => short_in,
      relay_out  => relay_out,
      fault_led  => fault_led,
      status_led => status_led
    );
end architecture rtl;
