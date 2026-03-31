# =============================================================
#   Vortex UVM - Run Sanity Test (Linux QuestaSim)
#
#   Usage:
#     vsim -c -do run_sanity.tcl
# =============================================================

transcript on

vsim -c work.vortex_tb_top \
    +UVM_TESTNAME=vortex_sanity_test \
    +UVM_VERBOSITY=UVM_LOW \
    -sv_seed random

run -all

quit -f