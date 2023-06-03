# Introduction

This project aims to create an embedded Linux system for Raspberry Pi.

# Work directory structure

```
WORKDIR/
├─ build/ (Compiled sources)
├─ data/ (Data to copy, needed by the script)
│ ├─ boot_rpi/ (Files to copy to SD card boot directory)
│ ├─ configs_busybox/ (Saved busybox configuration files)
│ ├─ images/ (Framebuffer test images)
| ├─ makefiles/ (Makefiles which will be copied in some source folders)
│ ├─ azerty.kmap
│ ├─ inittab
│ ├─ rcS
├─ docs/ (Documentation)
├─ logs/ (Installation logs, created by the script)
├─ src/ (Sources)
│ ├─ fbv/
│ | ├─ fbv-master.zip (FBV sources)
│ | ├─ jpegsrc.v9e.tar.gz (JPEG lib sources)
│ | ├─ libpng-x.x.x.tar.gz (PNG lib sources)
│ | ├─ zlib-x.x.x.tar.gz (Zlib lib sources)
│ ├─ hello_world/ (Cross-compilation test program)
| ├─ ncurses/
│ | ├─ ncurses-x.x.tar.gz (Ncurses sources)
│ | ├─ ncurses-examples.tar.gz
│ | ├─ ncurses_programs.tar.gz
│ | ├─ hello_ncurses/ (Ncurses test program)
│ ├─ busybox-x.x.x.tar.bz2 (Busybox sources)
│ ├─ tools-master.zip (Cross-compilation tools)
│ ├─ dropbear-xxxx.x.tar.bz2 (Dropbear sources)
├─ targets/ (Cross-compilation targets)
├─ mk_env.sh (Build environment creation script)
├─ script.sh
```

# Usage

## Prerequisites

In the data directory:
- `boot_rpi` folder containing the files to be copied in the boot directory of the SD card
- `configs_busybox` folder containing saved busybox configuration files
- `images` folder containing test images for framebuffer
- `makefiles` folder containing the makefiles which will be copied in some sources folders
- `azerty.kmap` file containing the keyboard layout
- `inittab` script containing the init configuration
- `rcS` script executed on startup

## Launching the script

The script must be run from the `WORKDIR` folder as root.

```bash
sudo ./script.sh
```

## Script usage

1. Unpacking sources

2. Selection of the storage device (SD card)

3. Selecting the busybox configuration file (or first modifying the configuration file then saving it)

4. Step-by-step installation or quick installation
