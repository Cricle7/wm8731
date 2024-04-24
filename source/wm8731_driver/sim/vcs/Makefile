all:clean anly elb

sim:all
	./simv
verdi:all
	./simv -verdi

ANLY_FL = sim_file_list.f
ANLY_FL := $(addprefix -f , $(ANLY_FL))
# ANLY_DEF :=$(ANLY_DEF) +define+IPSL_PCIE_SPEEDUP_SIM +define+DWC_DISABLE_CDC_METHOD_REPORTING +define+IPML_HSST_SPEEDUP_SIM
ANLY_FLAGS := $(ANLY_FLAGS) -full64 -sverilog -kdb -lca  -override_timescale=1ns/10ps
ANLY_LOGS = vlogan.log
anly:
	vlogan $(ANLY_FLAGS) $(ANLY_DEF)  $(ANLY_FL) -l $(ANLY_LOGS)
ELB_TOP := work.resample_tb
ELB_FLAGS := $(ELB_FLAGS) -full64 -debug_all -kdb -lca -j20
ELB_LOGS = vcs.log
ELB_LINK := $(ELB_LINK) -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a 
elb:
	vcs $(ELB_TOP) $(ELB_FLAGS) $(ELB_LINK) -l $(ELB_LOGS)  
clean:
	$(RM) -rf *.fsdb.* work csrc simv* verdi* veri* simv ucli.key vlog.log vsim.log *.fsdb novas* simv.*