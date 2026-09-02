# Update, 2026-09-02

The conclusion in the previous commit ("this is not a fix") rested on a
single build. Gowin place-and-route is not deterministic on this design
at 97% cluster utilisation, so one build booting or not says nothing
about the source.

Counted properly, holding DTACK while the flash ROM is busy is part of
the configuration that now runs on this board: see commit 394f091 on
branch `nano20k-running` (drive sounds, registered audio path, rom_wait).
The change that actually moved the boot rate was registering the audio
path before the HDMI clock crossing, which took the sample ROMs out of
the worst timing path.
