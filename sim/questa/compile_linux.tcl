# =============================================================
#   Vortex UVM - Compilation Script (Linux QuestaSim)
#   
#   Usage:
#     cd ~/Vortex-UVM-GP/vortex_uvm_env/sim/questa
#     vsim -c -do compile_linux.tcl
#
#   Compiles in dependency order:
#     1. UVM package
#     2. Config package  (interfaces depend on this)
#     3. TB interfaces
#     4. Agent packages  (transactions first)
#     5. UVM env components
#     6. Testbench top
#     7. Tests
# =============================================================

transcript on

# ---------------- CREATE WORK LIBRARY ------------------------
if {![file exists "work"]} {
    vlib work
}
vmap work work

# ---------------- SET PATHS ----------------------------------
set VORTEX_ROOT  "$env(HOME)/Vortex-UVM-GP/Vortex"
set UVM_ROOT     "$env(HOME)/Vortex-UVM-GP/vortex_uvm_env"
set TB_ROOT      "$UVM_ROOT/tb"
set ENV_ROOT     "$UVM_ROOT/uvm_env"
set AGENT_ROOT   "$ENV_ROOT/agents"
set TEST_ROOT    "$UVM_ROOT/uvm_tests"
set UVM_HOME     "$env(UVM_HOME)"

# Headers are in tb/ (VX_config.vh, VX_define.vh, etc.)
# UVM_HOME added so uvm_macros.svh is found by all files
set INC "+incdir+$TB_ROOT +incdir+$ENV_ROOT +incdir+$AGENT_ROOT +incdir+$UVM_HOME"

puts "============================================================="
puts " Paths:"
puts "   VORTEX_ROOT : $VORTEX_ROOT"
puts "   UVM_ROOT    : $UVM_ROOT"
puts "   TB_ROOT     : $TB_ROOT"
puts "   UVM_HOME    : $UVM_HOME"
puts "============================================================="

# ---------------- 1. UVM PACKAGE -----------------------------
puts "\n--- Step 1: Compiling UVM package ---"
vlog -sv -suppress 2167 \
    +incdir+$UVM_HOME \
    $UVM_HOME/uvm_pkg.sv

# ---------------- 2. CONFIG PACKAGE -------------------------
# Must come before interfaces - interfaces import vortex_config_pkg
puts "\n--- Step 2: Compiling config package ---"
vlog -sv $INC \
    $ENV_ROOT/vortex_config.sv

# ---------------- 3. TB INTERFACES --------------------------
puts "\n--- Step 3: Compiling TB interfaces ---"
vlog -sv $INC \
    $TB_ROOT/VX_config.vh \
    $TB_ROOT/VX_define.vh \
    $TB_ROOT/VX_platform.vh \
    $TB_ROOT/VX_types.vh \
    $TB_ROOT/vortex_mem_if.sv \
    $TB_ROOT/vortex_axi_if.sv \
    $TB_ROOT/vortex_dcr_if.sv \
    $TB_ROOT/vortex_status_if.sv \
    $TB_ROOT/vortex_if.sv

# ---------------- 4. AGENT PACKAGES -------------------------
# Each agent uses `include inside its package file to pull in all components.
# Compile ONLY the package file - do NOT compile individual files separately
# as they are already included by the package and would cause circular errors.

puts "\n--- Step 4a: mem_agent ---"
vlog -sv $INC \
    +incdir+$AGENT_ROOT/mem_agent \
    $AGENT_ROOT/mem_agent/mem_agent_pkg.sv

puts "\n--- Step 4b: axi_agent ---"
vlog -sv $INC \
    +incdir+$AGENT_ROOT/axi_agent \
    $AGENT_ROOT/axi_agent/axi_agent_pkg.sv

puts "\n--- Step 4c: dcr_agent ---"
vlog -sv $INC \
    +incdir+$AGENT_ROOT/dcr_agent \
    $AGENT_ROOT/dcr_agent/dcr_agent_pkg.sv

puts "\n--- Step 4d: host_agent ---"
vlog -sv $INC \
    +incdir+$AGENT_ROOT/host_agent \
    $AGENT_ROOT/host_agent/host_agent_pkg.sv

puts "\n--- Step 4e: status_agent ---"
vlog -sv $INC \
    +incdir+$AGENT_ROOT/status_agent \
    $AGENT_ROOT/status_agent/status_agent_pkg.sv

# ---------------- 5. UVM ENV COMPONENTS ---------------------
# vortex_env_pkg.sv uses `include to pull in all env components
# (virtual_sequencer, scoreboard, coverage_collector, env).
# Compile ONLY the package file - same pattern as agent packages.
puts "\n--- Step 5: Compiling UVM env package ---"
vlog -sv $INC \
    +incdir+$ENV_ROOT \
    $ENV_ROOT/vortex_env_pkg.sv

# ---------------- 6. TESTBENCH TOP --------------------------
puts "\n--- Step 6: Compiling testbench top ---"
vlog -sv $INC \
    $TB_ROOT/vortex_tb_top.sv

# ---------------- 7. TESTS ----------------------------------
puts "\n--- Step 7: Compiling tests ---"
vlog -sv $INC \
    $TEST_ROOT/vortex_base_test.sv \
    $TEST_ROOT/vortex_sanity_test.sv \
    $TEST_ROOT/vortex_smoke_test.sv \
    $TEST_ROOT/functional_memory_test.sv \
    $TEST_ROOT/vortex_test_pkg.sv

# ---------------- DONE --------------------------------------
puts "\n============================================================="
puts " Compilation complete."
puts " To run sanity test:"
puts "   vsim -c -do run_sanity.tcl"
puts "   or: vsim work.vortex_tb_top +UVM_TESTNAME=vortex_sanity_test"
puts "============================================================="

quit -f