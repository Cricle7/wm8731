#!/bin/csh -f

cd /mnt/d/Project/FPGA_project/WM8731/source/wm8731_driver/sim/vcs

#This ENV is used to avoid overriding current script in next vcselab run 
setenv SNPS_VCSELAB_SCRIPT_NO_OVERRIDE  1

/usr/synopsys/vcs/T-2022.06/linux64/bin/vcselab $* \
    -o \
    simv \
    -nobanner \

cd -

