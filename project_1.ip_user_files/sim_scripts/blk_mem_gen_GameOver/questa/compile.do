vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xil_defaultlib

vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vcom -work xil_defaultlib  -93 \
"../../../../project_1.gen/sources_1/ip/blk_mem_gen_GameOver/blk_mem_gen_GameOver_sim_netlist.vhdl" \


