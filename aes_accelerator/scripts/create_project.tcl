##-----------------------------------------------------------------------------
## Vivado Project Creation Script
## AES-128 CBC Accelerator for Zynq XC7Z020CLG400-1
##
## Usage: vivado -mode batch -source create_project.tcl
##        or from Vivado Tcl Console: source create_project.tcl
##-----------------------------------------------------------------------------

# Project settings
set project_name "aes_accelerator"
set project_dir  "../vivado_project"
set part         "xc7z020clg400-1"
set board        "tul.com.tw:pynq-z2:part0:1.0"

# Get script directory
set script_dir [file dirname [info script]]
set src_dir    [file normalize "$script_dir/../rtl"]
set tb_dir     [file normalize "$script_dir/../tb"]
set constr_dir [file normalize "$script_dir/../constraints"]

# Create project
create_project $project_name $project_dir -part $part -force

# Set board (optional — comment out if board files not installed)
# set_property board_part $board [current_project]

# Set target language
set_property target_language Verilog [current_project]

##=============================================================================
## Add RTL Sources
##=============================================================================
add_files -norecurse [glob $src_dir/*.v]
set_property file_type {Verilog} [get_files [glob $src_dir/*.v]]

# Set top module
set_property top aes_top [current_fileset]

##=============================================================================
## Add Testbench Sources (simulation only)
##=============================================================================
set sim_fileset [get_filesets sim_1]
add_files -fileset $sim_fileset -norecurse [glob $tb_dir/*.v]
set_property file_type {Verilog} [get_files -of_objects $sim_fileset [glob $tb_dir/*.v]]

# Set simulation top for each testbench
set_property top tb_aes_pipeline $sim_fileset
set_property top_lib xil_defaultlib $sim_fileset

##=============================================================================
## Add Constraints
##=============================================================================
add_files -fileset constrs_1 -norecurse $constr_dir/xc7z020.xdc
set_property file_type {XDC} [get_files $constr_dir/xc7z020.xdc]

##=============================================================================
## Create Block Design with Zynq PS (optional)
##=============================================================================
proc create_bd {} {
    # Create block design
    create_bd_design "zynq_aes_system"

    # Add Zynq PS
    set zynq [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]
    
    # Configure Zynq PS
    set_property -dict [list \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
    ] $zynq

    # Apply board preset (if board files installed)
    # apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    #     -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $zynq

    # Add AES accelerator as RTL module
    set aes [create_bd_cell -type module -reference aes_top aes_top_0]

    # Add AXI interconnect
    set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
    set_property CONFIG.NUM_MI {1} $axi_ic
    set_property CONFIG.NUM_SI {1} $axi_ic

    # Connect clocks and resets
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins aes_top_0/S_AXI_ACLK] \
        [get_bd_pins axi_interconnect_0/ACLK] \
        [get_bd_pins axi_interconnect_0/S00_ACLK] \
        [get_bd_pins axi_interconnect_0/M00_ACLK]

    connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
        [get_bd_pins aes_top_0/S_AXI_ARESETN] \
        [get_bd_pins axi_interconnect_0/ARESETN] \
        [get_bd_pins axi_interconnect_0/S00_ARESETN] \
        [get_bd_pins axi_interconnect_0/M00_ARESETN]

    # Connect AXI interfaces
    connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
        [get_bd_intf_pins axi_interconnect_0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
        [get_bd_intf_pins aes_top_0/S_AXI]

    # Assign address
    create_bd_addr_seg -range 0x00001000 -offset 0x43C00000 \
        [get_bd_addr_spaces processing_system7_0/Data] \
        [get_bd_addr_segs aes_top_0/S_AXI/reg0] SEG_aes_top_0_reg0

    # Validate and save
    validate_bd_design
    save_bd_design

    # Generate wrapper
    make_wrapper -files [get_files zynq_aes_system.bd] -top
    add_files -norecurse [glob $project_dir/$project_name.gen/sources_1/bd/zynq_aes_system/hdl/*.v]
    set_property top zynq_aes_system_wrapper [current_fileset]
}

# Uncomment to auto-create block design:
# create_bd

##=============================================================================
## Synthesis & Implementation Settings
##=============================================================================
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]

puts "============================================================"
puts "  Project created successfully: $project_name"
puts "  Part: $part"
puts "  Top module: aes_top"
puts "============================================================"
puts "  Next steps:"
puts "    1. Open project in Vivado GUI"
puts "    2. Run 'create_bd' to create Zynq block design (optional)"
puts "    3. Run synthesis: launch_runs synth_1 -jobs 4"
puts "    4. Run implementation: launch_runs impl_1 -jobs 4"
puts "    5. Generate bitstream: write_bitstream"
puts "============================================================"
