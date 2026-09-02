//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-4
//Created Time: 2023-09-22 09:53:28
create_clock -name clk_hdmi -period 6.25 -waveform {0 3.125} [get_nets {video2hdmi/clk_pixel_x5}] -add
create_clock -name clk_spi -period 10 -waveform {0 5} [get_ports {mspi_clk}] -add
create_clock -name clk_osc -period 37 -waveform {0 18} [get_ports {clk}] -add
create_clock -name clk_32 -period 31 -waveform {0 15} [get_ports {O_sdram_clk}] -add
// The core's 32MHz domain is driven by clk_div_5, not by the O_sdram_clk port
// that the existing clk_32 constraint sits on; the analyzer invents a default
// clock for it ("determined to be a clock but was not created"). Name it, name
// the 48kHz audio toggle, and mark the two as unrelated: audio words are quasi
// static and resampled, the crossing is not a timing path. Without this the
// ROM -> mixer -> packetizer crossing is the worst violator of every build
// (-18ns) and steers placement.
create_clock -name clk_core -period 31.25 -waveform {0 15.625} [get_pins {clk_div_5/clkdiv_inst/CLKOUT}] -add
create_clock -name clk_audio -period 20833.333 -waveform {0 10416.667} [get_nets {video2hdmi/clk_audio}] -add
set_clock_groups -asynchronous -group [get_clocks {clk_core}] -group [get_clocks {clk_audio}]
