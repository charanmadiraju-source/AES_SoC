##-----------------------------------------------------------------------------
## Vivado Simulation Script
## AES-128 CBC Accelerator Testbenches
##
## Usage: vivado -mode batch -source run_sim.tcl
##        or from Vivado Tcl Console: source run_sim.tcl
##
## Runs all three testbenches sequentially and reports results
##-----------------------------------------------------------------------------

# Get script directory
set script_dir [file dirname [info script]]
set src_dir    [file normalize "$script_dir/../rtl"]
set tb_dir     [file normalize "$script_dir/../tb"]
set sim_dir    [file normalize "$script_dir/../sim_output"]

# Create simulation output directory
file mkdir $sim_dir

puts "============================================================"
puts "  AES-128 CBC Accelerator - Simulation Suite"
puts "============================================================"

##=============================================================================
## Test 1: AES Pipeline (raw encryption)
##=============================================================================
puts "\n--- Running: tb_aes_pipeline ---"

# Read all source files
set src_files [glob $src_dir/*.v]
set tb_file "$tb_dir/tb_aes_pipeline.v"

# Run xvlog (compile)
exec xvlog {*}$src_files $tb_file -log $sim_dir/xvlog_pipeline.log

# Run xelab (elaborate)
exec xelab tb_aes_pipeline -s sim_pipeline \
    -log $sim_dir/xelab_pipeline.log \
    -debug typical

# Run xsim (simulate)
exec xsim sim_pipeline -runall \
    -log $sim_dir/xsim_pipeline.log \
    -tclbatch [list]

puts "  Pipeline test complete. Log: $sim_dir/xsim_pipeline.log"

##=============================================================================
## Test 2: AES CBC mode
##=============================================================================
puts "\n--- Running: tb_aes_cbc ---"

set tb_file "$tb_dir/tb_aes_cbc.v"

exec xvlog {*}$src_files $tb_file -log $sim_dir/xvlog_cbc.log
exec xelab tb_aes_cbc -s sim_cbc \
    -log $sim_dir/xelab_cbc.log \
    -debug typical
exec xsim sim_cbc -runall \
    -log $sim_dir/xsim_cbc.log \
    -tclbatch [list]

puts "  CBC test complete. Log: $sim_dir/xsim_cbc.log"

##=============================================================================
## Test 3: AES Top with AXI4-Lite
##=============================================================================
puts "\n--- Running: tb_aes_top ---"

set tb_file "$tb_dir/tb_aes_top.v"

exec xvlog {*}$src_files $tb_file -log $sim_dir/xvlog_top.log
exec xelab tb_aes_top -s sim_top \
    -log $sim_dir/xelab_top.log \
    -debug typical
exec xsim sim_top -runall \
    -log $sim_dir/xsim_top.log \
    -tclbatch [list]

puts "  Top-level test complete. Log: $sim_dir/xsim_top.log"

##=============================================================================
## Summary
##=============================================================================
puts "\n============================================================"
puts "  All simulations complete!"
puts "  Check logs in: $sim_dir/"
puts "============================================================"

##=============================================================================
## Alternative: Run with Icarus Verilog (if Vivado not available)
##=============================================================================
## To run with Icarus Verilog instead:
##
##   # Pipeline test
##   iverilog -o sim_pipeline -s tb_aes_pipeline rtl/*.v tb/tb_aes_pipeline.v
##   vvp sim_pipeline
##
##   # CBC test
##   iverilog -o sim_cbc -s tb_aes_cbc rtl/*.v tb/tb_aes_cbc.v
##   vvp sim_cbc
##
##   # Top-level test
##   iverilog -o sim_top -s tb_aes_top rtl/*.v tb/tb_aes_top.v
##   vvp sim_top
