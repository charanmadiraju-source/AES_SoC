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
## FCLK_CLK0 from Zynq PS — configured to 100 MHz in the block design.
## In the block design flow (default) Vivado auto-derives this clock from the
## PS7 primitive, so no explicit create_clock is needed here.
##
## If running a standalone RTL synthesis outside the block design (e.g., for
## early timing analysis with aes_top as the top module), add the following
## to a separate simulation/synthesis XDC:
##   create_clock -period 10.000 -name clk_100mhz [get_ports S_AXI_ACLK]
## =============================================================================

## =============================================================================
## Configuration / Bitstream Settings
## =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## =============================================================================
## Power Optimization
## =============================================================================
## Power optimization is run as a flow step (power_opt_design command), not
## as a design property.  Enable it in the implementation run settings if needed.

## =============================================================================
## Implementation Strategy
## =============================================================================
## Directive overrides for placement/routing are set in create_project.tcl via
## set_property on the impl_1 run object.  They are not valid in an XDC file.

## =============================================================================
## Area Constraints (optional - uncomment to constrain AES to specific region)
## =============================================================================
## create_pblock pblock_aes
## add_cells_to_pblock [get_pblocks pblock_aes] [get_cells u_dut/u_aes_cbc]
## resize_pblock [get_pblocks pblock_aes] -add {SLICE_X0Y0:SLICE_X50Y99}
