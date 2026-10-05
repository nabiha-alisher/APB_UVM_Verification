# Makefile
TEST 		= apb_wr_rd_test
TIME_OUT	= 9200000


# to compile the code on vcs, run `make compile` command in the terminal
compile:
	vcs -sverilog -f build_flist.f -ntb_opts uvm-1.2 +UVM_TESTNAME=$(TEST) -cm line+cond+tgl+assert +UVM_TIMEOUT=$(TIME_OUT) -LDFLAGS -Wl,--no-as-needed -full64 -debug_all 
	cd ./out && rm -rf build_$(TEST)
	cd ./out && mkdir build_$(TEST)
	mv csrc simv.daidir simv.vdb simv vc_hdrs.h ./out/build_$(TEST)

# for simulation, run `make sim` command in the terminal
sim: 
	cd ./out/build_$(TEST) && ./simv -cm line+cond+tgl+assert +UVM_TESTNAME=$(TEST) +UVM_TIMEOUT=$(TIME_OUT)
# > log_build_$(TEST).log

# To view waveform, run `make gui` command in the terminal
gui: 
	cd ./out/build_$(TEST) && dve -vpd waveform.vpd	

# More advance make targets
cov:
	urg -report  ./out/coverage_report -dir  ./out/build_*/*.vdb


clean: 
	rm -rf ./out/build_$(TEST)

allclean:
	rm -rf ./out/*


dve_cov:
	dve -covdir simv.vdb

