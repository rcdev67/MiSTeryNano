//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-4
//Created Time: 2023-09-22 09:53:28
create_clock -name clk_hdmi -period 6.25 -waveform {0 3.125} [get_nets {video2hdmi/clk_pixel_x5}] -add
# The flash clock pin is the 100MHz flash PLL's phase-shifted output. As a
# primary clock on the output port it timed nothing (0 endpoints): the W25Q64FV
# drives data up to 7ns after the falling edge, and the capture into
# flash/dout at the next rising edge was never analyzed or placed for.
# 27MHz * 2 = 54MHz (was 100MHz: at 10ns the state->pad path of ~9ns and the 2ns
# flash setup did not fit, and the read capture sat on the first/second edge
# boundary). CLKOUTP is CLKOUT shifted by 337.5 degrees (1.16ns
# early); that shift is folded into the delay values below.
create_clock -name clk_flash -period 18.519 -waveform {0 9.259} [get_pins {pll_flash/rpll_inst/CLKOUT}] -add
create_clock -name clk_flash_p -period 18.519 -waveform {0 9.259} [get_pins {pll_flash/rpll_inst/CLKOUTP}] -add
# (a generated clock on the mspi_clk port is ignored by Gowin, TA1052: clk_flash_p
#  already propagates to the pin, so the IO delays reference it directly)
create_clock -name clk_osc -period 37 -waveform {0 18} [get_ports {clk}] -add
# The SDRAM clock is the inverted core clock (sdram.v: sd_clk = ~clk). As a
# primary clock on the output port the analyzer could not relate it to the
# core clock (CK3000), so nothing between the FPGA and the in-package SDRAM
# was ever timed: read data is captured in the fabric through a mux, and
# whether that capture works depended on where the placer happened to put it.
create_generated_clock -name clk_sdram -source [get_pins {clk_div_5/clkdiv_inst/CLKOUT}] -invert [get_ports {O_sdram_clk}]
// The core's 32MHz domain is driven by clk_div_5, not by the O_sdram_clk port
// that the existing clk_32 constraint sits on; the analyzer invents a default
// clock for it ("determined to be a clock but was not created"). Name it, name
// the 48kHz audio toggle, and mark the two as unrelated: audio words are quasi
// static and resampled, the crossing is not a timing path. Without this the
// ROM -> mixer -> packetizer crossing is the worst violator of every build
// (-18ns) and steers placement.
create_clock -name clk_core -period 31.25 -waveform {0 15.625} [get_pins {clk_div_5/clkdiv_inst/CLKOUT}] -add
create_clock -name clk_audio -period 20833.333 -waveform {0 10416.667} [get_nets {video2hdmi/clk_audio}] -add
# SPI link from the companion MCU. The BL616 on the Tang Nano 20K clocks it at
# 26MHz (the other boards use 13MHz), and the bit-select path from spi_cnt to
# spi_io_dout has half a period. Without this definition the placer ignores it.
# Named clk_mcu_spi: the original clk_spi is the flash clock on mspi_clk.
# Defined on the net behind the internal/M0S clock mux in top.sv: a clock on the
# port does not propagate through that LUT (TA1132 names this net).
create_clock -name clk_mcu_spi -period 38.46 -waveform {0 19.23} [get_nets {misterynano/mcu/n4_24}] -add
set_clock_groups -asynchronous -group [get_clocks {clk_core}] -group [get_clocks {clk_audio}] -group [get_clocks {clk_mcu_spi}] -group [get_clocks {clk_flash clk_flash_p}]

# Embedded SDR SDRAM: data valid tAC max ~6.5ns after its clock edge, held tOH
# ~2.5ns; it needs tS 1.5ns setup and tH 0.8ns hold on inputs.
set_input_delay -clock clk_sdram -max 6.5 [get_ports {IO_sdram_dq[*]}]
set_input_delay -clock clk_sdram -min 2.5 [get_ports {IO_sdram_dq[*]}]
set_output_delay -clock clk_sdram -max 1.5 [get_ports {IO_sdram_dq[*] O_sdram_addr[*] O_sdram_ba[*] O_sdram_dqm[*] O_sdram_cs_n O_sdram_ras_n O_sdram_cas_n O_sdram_wen_n O_sdram_cke}]
set_output_delay -clock clk_sdram -min -0.8 [get_ports {IO_sdram_dq[*] O_sdram_addr[*] O_sdram_ba[*] O_sdram_dqm[*] O_sdram_cs_n O_sdram_ras_n O_sdram_cas_n O_sdram_wen_n O_sdram_cke}]

# W25Q64FV, DSPI: tCLQV max 7ns from the falling clock edge (+1ns board), tCLQX
# min 1.5ns; inputs need tDVCH 2ns setup and tCHDX 3ns hold.
set_input_delay -clock clk_flash_p -clock_fall -max 6.9 [get_ports {mspi_do mspi_di}]
set_input_delay -clock clk_flash_p -clock_fall -min 2.7 [get_ports {mspi_do mspi_di}]
set_output_delay -clock clk_flash_p -max 2.0 [get_ports {mspi_do mspi_di mspi_cs}]
set_output_delay -clock clk_flash_p -min -3.0 [get_ports {mspi_do mspi_di mspi_cs}]
