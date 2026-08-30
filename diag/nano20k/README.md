# Diagnostic bitstreams for the Tang Nano 20K

Small standalone designs that instantiate **the core's own modules unchanged**
and expose otherwise invisible internal signals on the six board LEDs.

They exist because the ST is only released from reset when

```
resb = !system_reset[0] && !reset && !por && ram_ready && flash_ready && sd_ready
```

and none of `por`, `ram_ready` or `flash_ready` can be observed from outside.
When a board shows "no boot, black screen", these bitstreams tell you which
subsystem is at fault instead of guessing.

LED numbering is as on the board, LED0 being the one next to `S1`.

## Building

Requires the Gowin IDE (Education edition is sufficient for the GW2AR-18C).

```
cd diag/nano20k
gw_sh build_flash_test.tcl      # or build_flash_stress.tcl / build_sdram_test.tcl
openFPGALoader -b tangnano20k impl/pnr/flash_test.fs
```

The bitstream is loaded into SRAM only, so flash content (core + TOS) is left
untouched and a power cycle restores normal operation.

## flash_test — flash read path, single accesses

Uses `flash_dspi.v` and `flash_pll.v`. Reads the first two words of the primary
ST TOS slot at flash offset 0x100000.

| LED | meaning when lit |
|-----|------------------|
| 0 | `pll_lock_flash` — the 100 MHz flash PLL locked |
| 1 | `flash_ready` — controller finished its init phase |
| 2 | both reads completed |
| 3 | word at 0x100000 == 0x602E (TOS magic) |
| 4 | word at 0x100002 == 0x0104 (TOS version, expects TOS 1.04) |
| 5 | heartbeat, ~1 Hz, independent of PLL and flash |

If LED5 blinks but LED0 stays dark, the flash PLL does not lock and `por`
never deasserts in the real core.

## flash_stress — flash read path under sustained load

Reads the **entire** 192 KiB TOS image (98304 words) in an endless loop and
checks a 32 bit sum. One pass takes about 34 ms, so roughly 30 passes per
second. Catches intermittent errors that single accesses miss — relevant
because the 68000 fetches every opcode through this path.

`EXPECTED` in `flash_stress.v` is the sum of all big endian 16 bit words of the
TOS image and must be adjusted for a different TOS. For German TOS 1.04 it is
0x76919605.

| LED | meaning when lit |
|-----|------------------|
| 0 | `pll_lock_flash` |
| 1 | `flash_ready` |
| 2 | at least one full pass completed |
| 3 | every pass so far matched |
| 4 | **sticky fail** — at least one pass had a wrong checksum |
| 5 | activity, toggles roughly every 0.27 s |

## sdram_test — SDRAM data path

Uses `sdram.v`, `pll_160m.v` and `gowin_clkdiv.v`, i.e. the core's own
controller at its own 32 MHz clock with the magic port names. Writes and reads
back 32 words spread over all four banks and both halves of the 32 bit bus.

| LED | meaning when lit |
|-----|------------------|
| 0 | PLL locked |
| 1 | `ram_ready` |
| 2 | test completed |
| 3 | **PASS** — all values read back correctly |
| 4 | **FAIL** — at least one mismatch |
| 5 | heartbeat |

## Reporting

When asking for help, quoting the LED state of all three bitstreams turns
"it does not boot" into a precise statement about which subsystem fails.
