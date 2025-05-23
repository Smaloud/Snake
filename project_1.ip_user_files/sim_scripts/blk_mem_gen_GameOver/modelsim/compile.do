vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xil_defaultlib

vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vcom -work xil_defaultlib  -93 \
"../../../../project_1.gen/sources_1/ip/blk_mem_gen_GameOver/blk_mem_gen_GameOver_sim_netlist.vhdl" \


