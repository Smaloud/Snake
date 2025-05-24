-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
-- Date        : Sat May 24 11:05:35 2025
-- Host        : DESKTOP-TFS410 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub -rename_top blk_mem_gen_GameOver -prefix
--               blk_mem_gen_GameOver_ blk_mem_gen_GameOver_stub.vhdl
-- Design      : blk_mem_gen_GameOver
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity blk_mem_gen_GameOver is
  Port ( 
    clka : in STD_LOGIC;
    addra : in STD_LOGIC_VECTOR ( 19 downto 0 );
    douta : out STD_LOGIC_VECTOR ( 0 to 0 )
  );

end blk_mem_gen_GameOver;

architecture stub of blk_mem_gen_GameOver is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clka,addra[19:0],douta[0:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "blk_mem_gen_v8_4_4,Vivado 2020.2";
begin
end;
