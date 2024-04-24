if {[file exists work]} {
  file delete -force work  
}
vlib work
vmap work work

set LIB_DIR  C:/pango/PDS_2022.2-SP1-Lite/ip/system_ip/ipsxb_hmic_s/ipsxb_hmic_eval/ipsxb_hmic_s/../../../../../arch/vendor/pango/verilog/simulation

vlib work
vlog -sv -work work -mfcu -incr -f sim_file_list.f -y $LIB_DIR +libext+.v 
vsim -suppress 3486,3680,3781 +nowarn1 -c -sva -lib work resample_tb -l sim.log
add wave -position insertpoint sim:/resample_tb/adapt_filter_inst/*
add wave -position insertpoint sim:/resample_tb/adapt_filter_inst/filter_in_reg_16/*
add wave -position insertpoint sim:/resample_tb/adapt_filter_inst/u_coeff_reg/*
add wave -position insertpoint sim:/resample_tb/adapt_filter_inst/coeff_multiply/*
add wave -position insertpoint sim:/resample_tb/adapt_filter_inst/fir/*
run 15ms