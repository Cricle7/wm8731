if {[file exists work]} {
  file delete -force work  
}
vlib work
vmap work work

set LIB_DIR  C:/pango/PDS_2022.2-SP1-Lite/ip/system_ip/ipsxb_hmic_s/ipsxb_hmic_eval/ipsxb_hmic_s/../../../../../arch/vendor/pango/verilog/simulation

vlib work
vlog -sv -work work -mfcu -incr -f sim_file_list.f -y $LIB_DIR +libext+.v 
vsim -suppress 3486,3680,3781 +nowarn1 -c -sva -lib work multiply_accumulator_16bit_tb -l sim.log
add wave -position insertpoint sim:/multiply_accumulator_16bit_tb/U_multiply_accumulator_16bit/*
add wave -position insertpoint sim:/multiply_accumulator_16bit_tb/U_U_multiply_accumulator_16bit/*
run -all

