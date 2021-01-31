# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be
# similar to the information in those scripts but that seems hard to avoid.
#

# added "SW_VCS=2011.03 and "-full64" option -- awdeorio fall 2011
# added "-sverilog" and "SW_VCS=2012.09" option,
#	and removed deprecated Virsim references -- jbbeau fall 2013
# updated library path name -- jbbeau fall 2013

# VCS = SW_VCS=2017.12-SP2-1 vcs +v2k -sverilog +vc -Mupdate -line -full64 -cm line+tgl+cond+branch+fsm
VCS = SW_VCS=2017.12-SP2-1 vcs +v2k -sverilog +vc -Mupdate -line -full64 +define+DEBUG -cm line+tgl+cond+branch+fsm
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

all:    simv
	./simv -cm line+tgl+cond+branch+fsm | tee program.out
	urg -dir simv.vdb -format text
##### 
# Modify starting here
#####

TESTBENCH = verilog/freelist_test.sv

SIMFILES  = verilog/freelist.sv

HEADERS   = sys_defs.svh

# SYNTHESIS CONFIG
SYNTH_DIR = ./syn
SYNFILES  = $(SYNTH_DIR)/rs_super.vg

$(SYNFILES):	./verilog/rs_bank.sv ./verilog/rs_super.sv ./syn/rs_super.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./rs_super.tcl | tee rs_super_synth.out


#####
# Should be no need to modify after here
#####
sim:	simv $(ASSEMBLED)
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

.PHONY: sim


# updated interactive debugger "DVE", using the latest version of VCS
# awdeorio fall 2011
dve:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) +memcbk $(HEADERS) $(SIMFILES) $(TESTBENCH) -o dve -R -gui

dve_syn:	$(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) +memcbk $(HEADERS) $(TESTBENCH) $(SYNFILES) $(LIB) -o dve -R -gui

syn_simv:	$(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) $(HEADERS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out


clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf syn/*.vg syn/*.rep syn/*.ddc syn/*.chk *.log syn/*.syn
	rm -rf syn/*.out syn/command.log syn/*.db syn/*.svf syn/*.mr syn/*.pvl 
	rm -rf *.vdb syn/*.res syn/*_svsim.sv
	
.PHONY: dve clean nuke	
