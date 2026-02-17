##-----------------------------------------------------------------------------
## AES-128 CBC Accelerator - Xilinx Design Constraints
## Target: Xilinx Zynq-7000 XC7Z020CLG400-1
##
## This design is an AXI4-Lite peripheral connected to the Zynq PS via the
## M_AXI_GP0 port. All clocking comes from the PS FCLK_CLK0 output.
## No external I/O pins are required — the accelerator lives entirely
## within the PL fabric, connected to PS through the AXI interconnect.
##-----------------------------------------------------------------------------

## =============================================================================
## Clock Constraint
## FCLK_CLK0 from Zynq PS — configured to 100 MHz in Vivado block design
## =============================================================================
create_clock -period 10.000 -name clk_100mhz [get_pins u_zynq_ps/FCLK_CLK0]

## =============================================================================
## Timing Constraints
## =============================================================================

## Input delay constraints for AXI signals from PS (conservative estimate)
## PS to PL path through AXI interconnect
set_input_delay -clock clk_100mhz -max 3.0 [get_ports -filter {DIRECTION == IN}]
set_input_delay -clock clk_100mhz -min 1.0 [get_ports -filter {DIRECTION == IN}]

## Output delay constraints for AXI signals to PS
set_output_delay -clock clk_100mhz -max 3.0 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock clk_100mhz -min 1.0 [get_ports -filter {DIRECTION == OUT}]

## =============================================================================
## Configuration / Bitstream Settings
## =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## =============================================================================
## Power Optimization
## =============================================================================
## Enable clock gating for power savings on unused pipeline stages
set_property POWER_OPT ON [current_design]

## =============================================================================
## Implementation Strategy
## =============================================================================
## Target aggressive placement/routing for timing closure at 100 MHz
## The fully-pipelined AES core should close timing easily on XC7Z020
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

## =============================================================================
## Area Constraints (optional - uncomment to constrain AES to specific region)
## =============================================================================
## create_pblock pblock_aes
## add_cells_to_pblock [get_pblocks pblock_aes] [get_cells u_dut/u_aes_cbc]
## resize_pblock [get_pblocks pblock_aes] -add {SLICE_X0Y0:SLICE_X50Y99}
