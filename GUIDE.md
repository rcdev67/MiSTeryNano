# An Atari ST on a Tang Nano 20K: a guide to this fork

This is the guide I would have liked to have when I started. It covers
the setup I run and have tested: a Tang Nano 20K whose onboard BL616 runs
the companion, a USB hub for keyboard and mouse, and an ESP32-S3 as WiFi
modem and Bluetooth controller receiver. Everything here was tried on my
two boards (one of version 3921, one 3923); where something is only
partly known I say so.

The pieces, all on GitHub under `rcdev67`:

| Repository, branch | What it is |
|---|---|
| [MiSTeryNano](https://github.com/rcdev67/MiSTeryNano), `nano20k-running` | the FPGA core, the Atari ST itself (this repository) |
| [FPGA-Companion](https://github.com/rcdev67/FPGA-Companion), `net-download` | the firmware for the BL616: USB keyboard, mouse, joysticks, SD card, the on-screen menu |
| [Zimodem](https://github.com/rcdev67/Zimodem), `c3-supermini-misterynano` | the firmware for the ESP32: WiFi modem for the ST, file download for the companion, Bluetooth controller |

## 1. What you need

- a Tang Nano 20K and a microSD card (FAT32)
- an HDMI monitor, a USB keyboard and mouse, a plain USB hub with a USB-C
  plug (or a USB-C adapter for it)
- TOS ROM images (192 KB or 256 KB files). They are copyrighted by Atari
  and not part of this repository.
- a 5 V supply with 2 A
- optional, for network and wireless controller: an ESP32-S3 DevKitC-1,
  four jumper wires, an electrolytic capacitor of 470 µF or more
- optional, but it saves hours when something does not work: a USB serial
  adapter that manages 2 Mbaud (FTDI, CH340, CH343)

## 2. Setting it up

1. **Save the factory state** of the board, then flash the core, the TOS
   images and the companion. The board exists in two versions that need
   different companion images, and there are two traps (the companion does
   not start while the board hangs on a PC; flashing needs the S2 button
   once this core runs). All of that, with the commands, is in
   [TANG_NANO_20K.md](https://github.com/rcdev67/FPGA-Companion/blob/net-download/TANG_NANO_20K.md).
2. **TOS images** go into the flash, up to four of them:

   | Address | Used when the OSD says | I use |
   |---|---|---|
   | 0x100000 | Chipset ST or Mega ST, TOS Slot Primary | TOS 1.04 |
   | 0x140000 | Chipset STE, TOS Slot Primary | TOS 1.62 |
   | 0x180000 | Chipset ST or Mega ST, TOS Slot Secondary | TOS 2.06 |
   | 0x1C0000 | Chipset STE, TOS Slot Secondary | TOS 1.06 |

   An ST place wants a TOS for the ST (1.00 to 1.04, or 2.06), an STE place
   one for the STE (1.06, 1.62, 2.06). The title line of the OSD shows
   which version is actually running, so you never have to guess.
3. **The SD card** holds your disk images (`.ST`), hard disk images and
   the settings file `atarist.ini`, which the companion writes when you
   choose `Save settings`.
4. **Power and wiring**, see the next section. Then switch on, press F12.

## 3. Power: one source per rail

This is where most of my lost evenings went, so here are the rules first:

- The Tang has one 5 V rail with three ways in: its USB-C socket, its 5V
  pin, and a dock that feeds power back through the USB-C socket. **Use
  exactly one of them.** Two at once and the USB host does not come up:
  you get a picture, but keyboard and mouse are dead.
- **The hub always goes on the Tang's USB-C socket**, that is where the USB
  host sits. A plain hub without its own supply works, with keyboard and
  mouse on it. A USB-C dock with its own supply works too, but then it is
  the Tang's only source and the 5V pin stays free.
- While the Tang's USB-C socket hangs on a **computer**, the companion does
  not start at all (see TANG_NANO_20K.md). For normal use power it from a
  supply.
- **One supply for everything**: feed 5 V into the power rails of a
  breadboard, put the capacitor across the rails (long leg to 5 V), and
  run one pair of wires to the Tang (5V is the top pin of the right
  header, GND the one below it) and one pair to the ESP32-S3 (`5V` and
  `GND`). Do not power the S3 *through* the Tang from the Tang's 5V pin
  when the Tang itself is fed over USB-C: the S3 then resets whenever its
  radio starts.
- Mind the header: 5V and GND are neighbours. A printable label sheet for
  both pin headers is in [doc](doc).

The S3's signal wires: GPIO16 to pin 41, GPIO15 to pin 51, GPIO17 to
pin 54, as drawn in
[the wiring diagram](https://github.com/rcdev67/Zimodem/blob/c3-supermini-misterynano/doc/s3_wiring.svg).

## 4. The on-screen menu

F12 opens it; cursor keys, Return and Escape move around. Changes apply at
once but are only kept over a power cycle after `Settings`, `Save
settings`. The title line shows the running TOS version on the left and,
with a modem attached, its network address on the right.

**Disk A:** picks a floppy image for drive A. The ST notices the change by
itself, also between single and double sided disks.

**System**

| Entry | Choices | What it means |
|---|---|---|
| Chipset | ST, Mega ST, STE | ST is the classic machine. Mega ST adds the blitter, a chip that copies screen areas quickly; GEM gets snappier. STE is the enhanced machine: 4096 colours instead of 512, hardware scrolling, stereo sample sound, blitter, extra controller ports, and it starts the TOS from the STE place. Changing it cold boots the ST. |
| Memory | 4MB, 8MB | 4 MB is the most a real ST can have. 8 MB is a bonus of this core; TOS 2.06 counts it at start-up. No game needs it. It is for big applications (sequencers, DTP, RAM disks), and old software may trip over it, so leave it at 4MB unless you need more. Changing it cold boots the ST. |
| Video | Color, Mono | the monitor the ST believes it has. TOS looks at this only at start, so after changing it use `Reset`. Games want Color, the 640x400 high resolution for applications is Mono. |
| Cartridge | None, Cubase 2&3 | emulates the Cubase copy protection dongle |
| Mouse | USB, Atari ST, Amiga | USB for a mouse on the hub; the other two are for a real mouse on a DB9 adapter |
| Mouse cpi | 400 to 3200 | the resolution of your USB mouse; set it so that the pointer speed feels right |
| Joysticks | USB only, 1 Atari + USB, 2 Atari + USB | how many real DB9 joysticks you have wired. With `USB only` the first USB joystick or gamepad is the ST's joystick port 1, the one games use. A Bluetooth controller through the ESP32 always lands on port 1. |
| Serial | Companion, Ext. UART, Netz | where the ST's serial port goes. `Ext. UART`: to the modem on the pins 41/51, use it with a terminal program on the ST. `Netz`: the companion talks to the modem; the download menu switches to this by itself and back. `Companion`: the maintainers' built-in modem emulation, which needs a companion with its own network. |
| TOS Slot | Primary, Secondary | which of the two TOS places of the current chipset is used, see the table above. Use `Cold Boot` right after changing it. |
| Cold Boot | | restarts the ST with cleared memory |

**Storage:** floppy images for drives A and B, hard disk images for two
ACSI drives, and a write protection for the floppies.

**Settings**

| Entry | Choices | What it means |
|---|---|---|
| Screen | Standard, Overscan, Wide | how the ST picture is fitted onto the HDMI screen |
| Scanlines | None to 75% | darkens every other line like a tube monitor |
| Drive noise | Off to 100% | volume of the floppy drive sounds (motor and head), only heard during real disk activity |
| Volume | Mute to 100% | volume of the ST's sound |
| Save settings | | writes everything into `atarist.ini` on the card |

**Download...** loads files from a folder on your PC onto the SD card over
WiFi, see section 6. **Reset** is the ST's reset button.

## 5. Which settings for what

| You want to run | Chipset | TOS | Memory | Video |
|---|---|---|---|---|
| games | ST | 1.04; if a game complains about the TOS version, try the other slot | 4MB | Color |
| games and demos made for the STE | STE | 1.62 | 4MB | Color |
| GEM applications, word processing, MIDI | Mega ST or STE | 2.06 | 4MB, more if the program can use it | Mono |

If a game misbehaves, the plain ST with TOS 1.04 is the first thing to
try; cracked game disks in particular were made for that machine.

## 6. Getting software onto the ST

Put `.ST` images on the card with a PC, or let the ST fetch them:

1. `atarist.ini` on the card gets two lines, your WiFi and the PC:

       wifi=MyNetwork,MyPassword
       server=192.168.1.20:8888
       timezone=CEST

2. On the PC, in the folder with your images:

       python -m http.server 8888 --bind 192.168.1.20

3. On the ST: F12, `Download...`, `Load file list`, pick a file. It lands
   on the card; then choose it under `Disk A:`. A 720 KB image takes about
   half a minute.

The details, other modem boards and how it works are in
[DOWNLOAD.md](https://github.com/rcdev67/FPGA-Companion/blob/net-download/DOWNLOAD.md).

## 7. The clock, and what an accessory is

With a modem attached the ST gets the right date and time by itself: once
the modem is online the companion takes the time from it and sets the ST's
clock. The `timezone` line in `atarist.ini` says which zone (a code such as
`CET`, `CEST`, `GMT`; without it you get UTC). The modem knows no daylight
saving rules, so in Germany write `CET` in winter and `CEST` in summer.
TOS reads the clock only once, when it starts, and at that moment the
modem is not online yet. So after switching on wait until the modem's
address stands in the OSD title (the companion shows it only after it has
set the clock), then use `Reset`: from then on date and time are right.
Without that reset TOS keeps the date it started with, 1989 with TOS 1.04.
I have seen this work with TOS 1.04 and TOS 2.06. If the clock stays wrong,
`NETLOG.TXT` on the SD card tells what happened (`clock set: ...`, or why
not).

The easiest place to see the clock is the **control panel**, and that is
an *accessory*: a small helper program with the ending `.ACC` that TOS
loads at start from the root of the disk in drive A, up to six of them.
They then sit in the leftmost menu of the desktop (`Desk`) and can be
opened at any time, even while another program runs. The control panel
(`CONTROL.ACC`) came on Atari's own system disk, together with a terminal
emulator accessory, ST BASIC and more. Put that disk into drive A, reset,
and `Desk` offers the control panel with date, time, key repeat, mouse
speed and colours. Accessories are loaded only at start and only from
drive A, so a game disk in the drive means no accessories, which is what
you want for games.

## 8. Controllers

USB joysticks and gamepads go on the hub. A Bluetooth Low Energy
controller (tested: Xbox Series) pairs with the ESP32-S3 and arrives as
joystick port 1: hold the controller's pair button until its light blinks
fast, wait until it stays lit. From then on it reconnects by itself. The
companion's own menu (Shift+F12) has an entry `Controller...` that shows
which controller is connected and can start pairing a new one. The bond
lives in the ESP32, so the controller follows that board, not the Tang.
PlayStation and Switch controllers use classic Bluetooth, which the S3
does not have. More in the Zimodem fork's
[MISTERYNANO.md](https://github.com/rcdev67/Zimodem/blob/c3-supermini-misterynano/MISTERYNANO.md).

## 9. When something does not work

| What you see | What it was for me |
|---|---|
| Picture, but keyboard and mouse dead | two power sources on the Tang (a dock with its supply plus the 5V pin), or the USB-C socket hangs on a computer |
| The ST starts in colour with a plain desktop although the ini says otherwise, F12 does nothing | the companion is not running: wrong image for the board version, or the board hangs on a computer |
| `no device found` when flashing the core | S2 was not held while plugging the board in |
| A game shows garbage or does not start | Video is on Mono: set Color and `Reset`; or the wrong chipset or TOS for it |
| `Modem has no WiFi` | the `wifi=` line is missing or wrong; the result of the join is in `NETLOG.TXT` on the card |
| The ESP32 restarts when WiFi comes up | its 5 V comes through a thin jumper or through the Tang; feed it from the common rail and add the capacitor |
| The PC no longer sees a board or adapter on some USB sockets | a short between 5V and GND tripped the PC's port protection; `tools/usbports.ps1` in the companion fork shows `DeviceCausedOvercurrent` for such a socket |

Still open on my side: Arkanoid does not react to my mouse while Lemmings
does; a Logitech wireless receiver registers a joystick that does not
exist.

The companion's debug console tells a lot: pin 48, 2,000,000 baud, see
TANG_NANO_20K.md.
