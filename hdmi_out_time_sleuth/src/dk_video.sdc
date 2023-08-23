//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.11 Education
//Created Time: 2023-08-16 19:07:26
create_clock -name clock -period 37.037 -waveform {0 18.518} [get_ports {clock}] -add
create_generated_clock -name clk_serial -source [get_ports {clock}] -master_clock clock -divide_by 4 -multiply_by 55 [get_nets {clk_serial}]
create_generated_clock -name clk_pixel -source [get_nets {clk_serial}] -master_clock clk_serial -divide_by 5 -multiply_by 1 [get_pins {video_clock_inst/clkdiv5_inst/CLKOUT}]
create_generated_clock -name clk2in -source [get_ports {clock}] -master_clock clock -divide_by 1 -multiply_by 1 [get_pins {video_clock_inst/pll2_inst/pllvr_inst/CLKIN}]
set_clock_groups -exclusive -group [get_clocks {clock}] -group [get_clocks {clk_serial}]
