#! /bin/bash 

# This script must be run as root, from the folder
# containing the script file (WORKDIR). Requires an SD card
# connected to the computer in order to install the system on it.
#
# Work directory structure :
#
# WORKDIR/
# ├─ build/ (Compiled sources)
# ├─ data/ (Data to copy, needed by the script)
# │ ├─ boot_rpi/ (Files to copy to SD card boot directory)
# │ ├─ configs_busybox/ (Saved busybox configuration files)
# │ ├─ images/ (Framebuffer test images)
# | ├─ makefiles/ (Makefiles which will be copied in some source folders)
# │ ├─ azerty.kmap
# │ ├─ inittab
# │ ├─ rcS
# ├─ docs/ (Documentation)
# ├─ logs/ (Installation logs, created by the script)
# ├─ src/ (Sources)
# │ ├─ fbv/
# │ | ├─ fbv-master.zip (FBV sources)
# │ | ├─ jpegsrc.v9e.tar.gz (JPEG lib sources)
# │ | ├─ libpng-x.x.x.tar.gz (PNG lib sources)
# │ | ├─ zlib-x.x.x.tar.gz (Zlib lib sources)
# │ ├─ hello_world/ (Cross-compilation test program)
# | ├─ ncurses/
# │ | ├─ ncurses-x.x.tar.gz (Ncurses sources)
# │ | ├─ ncurses-examples.tar.gz
# │ | ├─ ncurses_programs.tar.gz
# │ | ├─ hello_ncurses/ (Ncurses test program)
# │ ├─ busybox-x.x.x.tar.bz2 (Busybox sources)
# │ ├─ tools-master.zip (Cross-compilation tools)
# │ ├─ dropbear-xxxx.x.tar.bz2 (Dropbear sources)
# ├─ targets/ (Cross-compilation targets)
# ├─ mk_env.sh (Build environment creation script)
# ├─ script.sh

# --------------------------------------------------------------------------- #
#                              Global variables                               #
# --------------------------------------------------------------------------- #

WORKDIR=$(pwd)

DEVICE="" # Example : /dev/sda
BUSYBOX_CONFIG_FILE="" # Selected busybox config file name
LINUX_KERNEL_CONFIG_FILE="" # Selected linux kernel config file name

# Constants
BOOT_DIR="/mnt/rpi-boot/"
ROOT_DIR="/mnt/rpi-root/"
YES="y"
NO="n"

# Colors
NC='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Paths
PATH_CC=$WORKDIR/build/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
CROSS_PREFIX=$PATH_CC/arm-linux-gnueabihf-
CCC=${CROSS_PREFIX}gcc
CXX=${CROSS_PREFIX}g++
TARGET_PC=$WORKDIR/build/target_pc/
TARGET_PI=$WORKDIR/build/target_pi/

# --------------------------------------------------------------------------- #
#                        Menu & menu choice functions                         #
# --------------------------------------------------------------------------- #

function menu() {
    clear
    cd $WORKDIR

    # Display the menu
    printf "${CYAN}*** Menu ***${NC}\n"
    printf "1: Unpack sources"; print_unpack_sources_status; printf "\n"
    printf "2: Select device"; print_selected_device; printf "\n" 
    printf "3: Select busybox config file"; print_selected_busybox_config_file; printf "\n" 
    printf "4: Modify busybox config\n"
    printf "5: Start step by step installation\n"
    printf "6: Start quick installation\n"
    printf "7: Cleanup files\n"
    printf "q: Quit\n"
    printf "${CYAN}Choose an option : ${NC}"
    read CHOICE

    # Execute the chosen option
    # Some choices will generate logs inside the logs/ folder
    case $CHOICE in
        1) mc_unpack_sources ;;
        2) mc_select_device ;;
        3) mc_select_busybox_config_file ;;
        4) mc_modify_busybox_config ;;
        5) mc_step_by_step_install | tee $WORKDIR/logs/$(date +%Y%m%d_%H%M%S)_step-by-step-install.log ;;
        6) mc_quick_install | tee $WORKDIR/logs/$(date +%Y%m%d_%H%M%S)_quick-install.log ;;
        7) mc_cleanup_files ;;
        q) exit 0 ;;
        *) printf "${RED}Invalid option.${NC}\n" ;;
    esac

    wait_enter
    menu
}

function mc_unpack_sources() {
    clear
    cd $WORKDIR

    # Check if build folder exists
    if [ ! -d build ]; then
        mkdir $WORKDIR/build/

        if [ ! -d build ]; then
            printf "${RED}The \"build\" folder doesn't exist. Please create it.${NC}\n"
            return
        fi
    fi

    # Busybox
    if [ ! -f src/busybox-*.tar.bz2 ]; then
        printf "${RED}Busybox source archive not found.${NC}\n"
    elif [ -d build/busybox ]; then
        printf "${RED}Busybox already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking busybox...${NC}\n"
        printf "${CYAN}\tExtracting busybox archive to build folder...${NC}\n"
        tar -xf src/busybox-*.tar.bz2 -C build/ # Extract the archive
        if [ ! -d build/busybox ]; then
            printf "${CYAN}\tRenaming folder to \"busybox\"...${NC}\n"
            mv build/busybox* build/busybox # Rename the folder
        else
            printf "${RED}Not renaming folder : \"busybox\" already exists.${NC}\n"
        fi
    fi

    # Tools (master)
    if [ ! -f src/tools-master.zip ]; then
        printf "${RED}Tools source archive not found.${NC}\n"
    elif [ -d build/tools-master ]; then
        printf "${RED}Tools already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking tools...${NC}\n"
        printf "${CYAN}\tExtracting tools archive to build folder...${NC}\n"
        unzip -qq src/tools-master.zip -d build/ # Extract the archive
    fi

    # Cross compilation "Hello world" program
        if [ ! -d src/hello-world/ ]; then
        printf "${RED}Cross compilation hello world program source not found.${NC}\n"
    elif [ -d build/hello-world/ ]; then
        printf "${RED}Cross compilation hello world program already copied.${NC}\n"
    else
        printf "${CYAN}Copying cross compilation hello world program...${NC}\n"
        cp -r src/hello-world/ build/hello-world/
    fi

    sudo mkdir -p build/ncurses/

    # Ncurses
    if [ ! -f src/ncurses/ncurses-*.*.tar.gz ]; then
        printf "${RED}Ncurses source archive not found.${NC}\n"
    elif [ -d build/ncurses/ncurses/ ]; then
        printf "${RED}Ncurses already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking ncurses...${NC}\n"
        printf "${CYAN}\tExtracting ncurses archive to build folder...${NC}\n"
        tar -xf src/ncurses/ncurses-*.*.tar.gz -C build/ncurses/ # Extract the archive
        if [ ! -d build/ncurses/ncurses/ ]; then
            printf "${CYAN}\tRenaming folder to \"ncurses\"...${NC}\n"
            mv build/ncurses/ncurses-*.* build/ncurses/ncurses # Rename the folder
        else
            printf "${RED}Not renaming folder : \"ncurses\" already exists.${NC}\n"
        fi
    fi

    # Ncurses examples
    if [ ! -f src/ncurses/ncurses-examples.tar.gz ]; then
        printf "${RED}Ncurses examples source archive not found.${NC}\n"
    elif [ -d build/ncurses/ncurses-examples/ ]; then
        printf "${RED}Ncurses examples already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking ncurses examples...${NC}\n"
        printf "${CYAN}\tExtracting ncurses examples archive to build folder...${NC}\n"
        tar -xf src/ncurses/ncurses-examples.tar.gz -C build/ncurses/ # Extract the archive
        if [ ! -d build/ncurses/ncurses-examples/ ]; then
            printf "${CYAN}\tRenaming folder to \"ncurses-examples\"...${NC}\n"
            mv build/ncurses/ncurses-examples-* build/ncurses/ncurses-examples # Rename the folder
        else
            printf "${RED}Not renaming folder : \"ncurses-examples\" already exists.${NC}\n"
        fi
    fi

    # Ncurses programs
    if [ ! -f src/ncurses/ncurses_programs.tar.gz ]; then
        printf "${RED}Ncurses source archive not found.${NC}\n"
    elif [ -d build/ncurses/ncurses-programs/ ]; then
        printf "${RED}Ncurses already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking ncurses programs...${NC}\n"
        printf "${CYAN}\tExtracting ncurses programs archive to build folder...${NC}\n"
        tar -xf src/ncurses/ncurses_programs.tar.gz -C build/ncurses/ # Extract the archive
        if [ ! -d build/ncurses/ncurses-programs/ ]; then
            printf "${CYAN}\tRenaming folder to \"ncurses-programs\"...${NC}\n"
            mv build/ncurses/ncurses_programs build/ncurses/ncurses-programs # Rename the folder
        else
            printf "${RED}Not renaming folder : \"ncurses-programs\" already exists.${NC}\n"
        fi
    fi

    # Ncurses "Hello World" program
    if [ ! -d src/ncurses/ncurses-hello/ ]; then
        printf "${RED}Ncurses hello world program source not found.${NC}\n"
    elif [ -d build/ncurses/ncurses-hello/ ]; then
        printf "${RED}Ncurses hello world program already copied.${NC}\n"
    else
        printf "${CYAN}Copying Ncurses hello world program...${NC}\n"
        cp -r src/ncurses/ncurses-hello/ build/ncurses/ncurses-hello/
    fi

    sudo mkdir -p build/fbv/

    # FBV
    if [ ! -f src/fbv/fbv-master.zip ]; then
        printf "${RED}FBV source archive not found.${NC}\n"
    elif [ -d build/fbv/fbv/ ]; then
        printf "${RED}FBV already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking FBV...${NC}\n"
        printf "${CYAN}\tExtracting FBV archive to build folder...${NC}\n"
        unzip -qq src/fbv/fbv-master.zip -d build/fbv/ # Extract the archive
        if [ ! -d build/fbv/fbv/ ]; then
            printf "${CYAN}\tRenaming folder to \"fbv\"...${NC}\n"
            mv build/fbv/fbv-master/ build/fbv/fbv/ # Rename the folder
        else
            printf "${RED}Not renaming folder : \"fbv\" already exists.${NC}\n"
        fi
    fi

    # JPEG lib
    if [ ! -f src/fbv/jpegsrc.v9e.tar.gz ]; then
        printf "${RED}JPEG lib source archive not found.${NC}\n"
    elif [ -d build/fbv/jpeg/ ]; then
        printf "${RED}JPEG lib already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking JPEG lib...${NC}\n"
        printf "${CYAN}\tExtracting JPEG lib archive to build folder...${NC}\n"
        tar -xf src/fbv/jpegsrc.v9e.tar.gz -C build/fbv/ # Extract the archive
        if [ ! -d build/fbv/jpeg/ ]; then
            printf "${CYAN}\tRenaming folder to \"jpeg\"...${NC}\n"
            mv build/fbv/jpeg-* build/fbv/jpeg/ # Rename the folder
        else
            printf "${RED}Not renaming folder : \"jpeg\" already exists.${NC}\n"
        fi
    fi

    # PNG lib
    if [ ! -f src/fbv/libpng-*.*.*.tar.gz ]; then
        printf "${RED}PNG lib source archive not found.${NC}\n"
    elif [ -d build/fbv/png/ ]; then
        printf "${RED}PNG lib already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking PNG lib...${NC}\n"
        printf "${CYAN}\tExtracting PNG lib archive to build folder...${NC}\n"
        tar -xf src/fbv/libpng-*.*.*.tar.gz -C build/fbv/ # Extract the archive
        if [ ! -d build/fbv/png/ ]; then
            printf "${CYAN}\tRenaming folder to \"png\"...${NC}\n"
            mv build/fbv/libpng-* build/fbv/png/ # Rename the folder
        else
            printf "${RED}Not renaming folder : \"png\" already exists.${NC}\n"
        fi
    fi

    # Z lib
    if [ ! -f src/fbv/zlib-*.*.*.tar.gz ]; then
        printf "${RED}Z lib source archive not found.${NC}\n"
    elif [ -d build/fbv/zlib/ ]; then
        printf "${RED}Z lib already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking Z lib...${NC}\n"
        printf "${CYAN}\tExtracting Z lib archive to build folder...${NC}\n"
        tar -xf src/fbv/zlib-*.*.*.tar.gz -C build/fbv/ # Extract the archive
        if [ ! -d build/fbv/zlib/ ]; then
            printf "${CYAN}\tRenaming folder to \"zlib\"...${NC}\n"
            mv build/fbv/zlib-* build/fbv/zlib/ # Rename the folder
        else
            printf "${RED}Not renaming folder : \"zlib\" already exists.${NC}\n"
        fi
    fi

    # Dropbear
    if [ ! -f src/dropbear-*.*.tar.bz2 ]; then
        printf "${RED}Dropbear source archive not found.${NC}\n"
    elif [ -d build/dropbear/ ]; then
        printf "${RED}Dropbear already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking dropbear...${NC}\n"
        printf "${CYAN}\tExtracting dropbear archive to build folder...${NC}\n"
        tar -xf src/dropbear-*.*.tar.bz2 -C build/ # Extract the archive
        if [ ! -d build/dropbear/ ]; then
            printf "${CYAN}\tRenaming folder to \"dropbear\"...${NC}\n"
            mv build/dropbear-* build/dropbear # Rename the folder
        else
            printf "${RED}Not renaming folder : \"dropbear\" already exists.${NC}\n"
        fi
    fi

    sudo mkdir -p build/wiringPi/

    # WiringPi
    if [ ! -f src/wiringPi/wiringPi-*.tar.gz ]; then
        printf "${RED}WiringPi source archive not found.${NC}\n"
    elif [ -d build/wiringPi/wiringPi/ ]; then
        printf "${RED}WiringPi already unpacked.${NC}\n"
    else
        printf "${CYAN}Unpacking wiringPi...${NC}\n"
        printf "${CYAN}\tExtracting wiringPi archive to build folder...${NC}\n"
        tar -xf src/wiringPi/wiringPi-*.tar.gz -C build/wiringPi/ # Extract the archive
        if [ ! -d build/wiringPi/wiringPi/ ]; then
            printf "${CYAN}\tRenaming folder to \"wiringPi\"...${NC}\n"
            mv build/wiringPi/wiringPi-* build/wiringPi/wiringPi # Rename the folder
        else
            printf "${RED}Not renaming folder : \"wiringPi\" already exists.${NC}\n"
        fi
    fi

    # WiringPi example programs
    if [ ! -d src/wiringPi/wiringPi-examples/ ]; then
        printf "${RED}WiringPi example programs source not found.${NC}\n"
    elif [ -d build/wiringPi/wiringPi-examples/ ]; then
        printf "${RED}WiringPi example programs already copied.${NC}\n"
    else
        printf "${CYAN}Copying WiringPi example programs...${NC}\n"
        cp -r src/wiringPi/wiringPi-examples/ build/wiringPi/wiringPi-examples/
    fi

    printf "${GREEN}Done.${NC}\n"
}

function mc_select_device() {
    clear
    cd $WORKDIR

    # Ask if the user wants to show the list of devices
    PROMPT="Show devices ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        show_devices
        printf "\n"
    fi

    # Choose device
    DEVICE=""
    while [ -z "$DEVICE" ]; do
        printf "${CYAN}Choose device (example: /dev/sda) : ${NC}"
        read DEVICE
    done

    printf "${GREEN}You chose the device \"${DEVICE}\".${NC}\n"
}

function mc_select_busybox_config_file() {
    clear
    cd $WORKDIR

    # Check if busybox folder exists
    if [ ! -d build/busybox ]; then
        printf "${RED}The \"build/busybox\" folder doesn't exist. Please unpack the sources first.${NC}\n"
        return
    fi

    # Check if configs folder exists
    if [ ! -d data/configs_busybox ]; then
        printf "${RED}The \"data/configs_busybox\" folder doesn't exist. Please create it.${NC}\n"
        return
    fi

    # Check if folder is empty
    if [ ! "$(ls -A data/configs_busybox)" ]; then
        printf "${RED}The \"data/configs_busybox\" folder is empty.${NC}\n"
        return
    fi

    # Show the list of config files
    cd data/configs_busybox
    printf "${CYAN}Select a busybox config file :${NC}\n"

    if [ -n "$BUSYBOX_CONFIG_FILE" ]; then
        printf "${GREEN}[Current: $BUSYBOX_CONFIG_FILE]${NC}\n"
    fi

    select CONFIG_FILE in $(ls -a | grep -v "^\.$" | grep -v "^\.\.$"); do
        if [ -n "$CONFIG_FILE" ]; then
            BUSYBOX_CONFIG_FILE=$CONFIG_FILE
            printf "${CYAN}Copying config file to \"build/busybox/.config\"...${NC}\n"
            cp $BUSYBOX_CONFIG_FILE $WORKDIR/build/busybox/.config # Copy the config file to the busybox folder
            printf "${GREEN}Selected config file : $BUSYBOX_CONFIG_FILE${NC}\n"
            break
        else
            printf "${RED}Invalid option.${NC}\n"
        fi
    done

}

function mc_modify_busybox_config() {
    clear
    cd $WORKDIR

    # Check if busybox folder exists
    if [ ! -d build/busybox ]; then
        printf "${RED}The \"build/busybox\" folder doesn't exist. Please unpack sources first.${NC}\n"
        return
    fi

    # Check if config file exists
    if [ ! -f build/busybox/.config ]; then
        printf "${RED}The \"build/busybox/.config\" file doesn't exist. Please add it or select a busybox config file.${NC}\n"
        return
    fi

    # Modify busybox config
    printf "${CYAN}Starting busybox menu config...${NC}\n"
    cd build/busybox && make menuconfig

    # If there was an error while modifying the config
    if [ $? -ne 0 ]; then
        printf "${RED}Error while modifying busybox config.${NC}\n"
        return
    fi
    
    printf "${GREEN}Busybox config modified.${NC}\n"

    # Ask if the user wants to save the config
    PROMPT="Save the config file ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        # Ask for the config file name
        while [ ! -n "$CONFIG_FILE_NAME" ]; do
            printf "${CYAN}Enter the config file name : ${NC}"
            read CONFIG_FILE_NAME
            if [ -n "$CONFIG_FILE_NAME" ]; then
                # Check if the file already exists
                if [ -f $WORKDIR/data/configs_busybox/$CONFIG_FILE_NAME ]; then
                    PROMPT="\"data/configs_busybox/$CONFIG_FILE_NAME\" already exists. Overwrite it ?"
                    DEFAULT_CHOICE=$YES
                    ask_prompt
                    if [ "$PROMPT_ANSWER" == "$NO" ]; then
                        CONFIG_FILE_NAME=""
                        continue
                    fi
                fi

                cp .config $WORKDIR/data/configs_busybox/$CONFIG_FILE_NAME
                printf "${GREEN}Config file saved at \"data/configs_busybox/$CONFIG_FILE_NAME\".${NC}\n"
            else
                printf "${RED}Invalid config file name.${NC}\n"
            fi
        done
    fi
}

function mc_step_by_step_install() {
    clear
    cd $WORKDIR

    ERROR=0

    # Check if device is set
    if [ ! -n "$DEVICE" ]; then
        printf "${RED}Please select a device.${NC}\n"
        ERROR=1
    fi

    # Check if busybox config file is set
    if [ ! -n "$BUSYBOX_CONFIG_FILE" ]; then
        printf "${RED}Please select a busybox config file.${NC}\n"
        ERROR=1
    fi

    # Check if there was an error
    if [ $ERROR -ne 0 ]; then
        return
    fi

    step_init

    # Unmount all partitions of device
    PROMPT="Unmount all partitions of ${DEVICE} ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Unmounting all partitions of ${DEVICE}...${NC}\n"
        step_unmount_device
        wait_clear
    fi

    # Delete partitions of device
    PROMPT="Delete all partitions of ${DEVICE} ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Deleting all partitions of ${DEVICE}...${NC}\n"
        step_delete_partitions
        wait_clear
    fi

    # Create new partition
    PROMPT="Create new partitions on ${DEVICE} ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Creating partitions...${NC}\n"
        step_create_partitions
        wait_clear
    fi

    # Format partition
    PROMPT="Format partitions ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Formatting partitions...${NC}\n"
        step_format_partitions
        wait_clear
    fi

    # Mount partition
    PROMPT="Mount partitions ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Mounting partitions...${NC}\n"
        step_mount_partitions
        wait_clear
    fi

    # Create target directory symlinks
    PROMPT="Create target directory symlinks ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Creating target directory symlinks...${NC}\n"
        step_create_targets
        wait_clear
    fi

    # Copy boot files to boot partition
    PROMPT="Copy boot files to boot partition ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Copying boot files to boot partition...${NC}\n"
        step_copy_boot_files
        wait_clear
    fi

    # Create base filesystem architecture
    PROMPT="Create base filesystem architecture ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Creating base filesystem architecture...${NC}\n"
        step_create_fs
        wait_clear
    fi

    # Install busybox
    PROMPT="Install busybox ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Installing busybox...${NC}\n"
        step_install_busybox
        wait_clear
    fi

    # Copy all the dynamic libraries used by busybox
    PROMPT="Copy all the dynamic libraries used by busybox ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Copying all the dynamic libraries used by busybox...${NC}\n"
        step_copy_busybox_libs
        wait_clear
    fi

    # Copy /etc/init.d/rcS
    PROMPT="Copy /etc/init.d/rcS ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Copying rcS...${NC}\n"
        step_copy_rcS
        wait_clear
    fi

    # Copy /etc/inittab
    PROMPT="Copy /etc/inittab ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Copying inittab...${NC}\n"
        step_copy_inittab
        wait_clear
    fi

    # Change keymap
    PROMPT="Change keyboard layout ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Changing keyboard layout...${NC}\n"
        step_copy_kmap
        wait_clear
    fi

    # Compile and copy hello world program
    PROMPT="Compile and copy hello world program ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Compiling and copying hello world program...${NC}\n"
        step_hello_world_program
        wait_clear
    fi

    # Copy libs
    PROMPT="Copy libs ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Copying libs...${NC}\n"
        step_copy_libs
        wait_clear
    fi

    # Compile ncurses
    PROMPT="Compile ncurses ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Compiling ncurses...${NC}\n"
        step_compile_ncurses
        wait_clear
    fi

    # Compile fbv
    PROMPT="Compile fbv ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Compiling fbv...${NC}\n"
        step_compile_fbv
        wait_clear
    fi

    # Add users
    PROMPT="Add users ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_add_users
        wait_clear
    fi

    # Configure network
    PROMPT="Configure network ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_configure_network
        wait_clear
    fi

    # Configure HTTP server
    PROMPT="Configure HTTP server ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_configure_http_server
        wait_clear
    fi

    # Configure SSH server
    PROMPT="Configure SSH server ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_configure_ssh_server
        wait_clear
    fi

    # Compile wiringPi
    PROMPT="Compile wiringPi ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_compile_wiringPi
        wait_clear
    fi

    # Copy images to pi
    PROMPT="Copy images to pi ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_copy_noot_noot
        wait_clear
    fi

        # Copy target_pi to pi
    PROMPT="Copy target_pi to pi ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        step_copy_target_pi
        wait_clear
    fi

    # Unmount device
    PROMPT="Unmount device ?"
    DEFAULT_CHOICE=$YES
    ask_prompt
    if [ "$PROMPT_ANSWER" == "$YES" ]; then
        printf "\n${CYAN}Unmounting device...${NC}\n"
        step_unmount_device
        wait_clear
    fi

    # End
    printf "\n${GREEN}Installation finished ! Press enter to continue...${NC}\n"
}

# Quick install will install the system without asking questions
function mc_quick_install() {
    clear
    cd $WORKDIR

    ERROR=0

    # Check if device is set
    if [ ! -n "$DEVICE" ]; then
        printf "${RED}Please select a device.${NC}\n"
        ERROR=1
    fi

    # Check if busybox config file is set
    if [ ! -n "$BUSYBOX_CONFIG_FILE" ]; then
        printf "${RED}Please select a busybox config file.${NC}\n"
        ERROR=1
    fi

    # Check if there was an error
    if [ $ERROR -ne 0 ]; then
        return
    fi

    step_init

    # Unmount all partitions of device
    printf "\n${CYAN}Unmounting all partitions of ${DEVICE}...${NC}\n"
    step_unmount_device

    # Delete partitions of device
    printf "\n${CYAN}Deleting partitions partitions of ${DEVICE}...${NC}\n"
    step_delete_partitions

    # Create new partition
    printf "\n${CYAN}Creating partitions...${NC}\n"
    step_create_partitions

    # Format partition
    printf "\n${CYAN}Formatting partitions...${NC}\n"
    step_format_partitions

    # Mount partition
    printf "\n${CYAN}Mounting partitions...${NC}\n"
    step_mount_partitions

    # Create target directory symlinks
    printf "\n${CYAN}Creating target directory symlinks...${NC}\n"
    step_create_targets

    # Copy boot files to boot partition
    printf "\n${CYAN}Copying boot files to boot partition...${NC}\n"
    step_copy_boot_files

    # Create base filesystem architecture
    printf "\n${CYAN}Creating base filesystem architecture...${NC}\n"
    step_create_fs

    # Install busybox
    printf "\n${CYAN}Installing busybox...${NC}\n"
    step_install_busybox

    # Copy all the dynamic libraries used by busybox
    printf "\n${CYAN}Copying dynamic libraries used by busybox...${NC}\n"
    step_copy_busybox_dynamic_libs

    # Copy etc/init.d/rcS 
    printf "\n${CYAN}Copying rcS...${NC}\n"
    step_copy_rcS

     # Copy etc/inittab
    printf "\n${CYAN}Copying inittab...${NC}\n"
    step_copy_inittab

    # Change keymap
    printf "\n${CYAN}Changing keyboard layout...${NC}\n"
    step_copy_kmap

    # Compile and copy hello world program
    printf "\n${CYAN}Compiling and copying hello world program...${NC}\n"
    step_hello_world_program

    # Copy libs
    printf "\n${CYAN}Copying libs...${NC}\n"
    step_copy_libs

    # Compile ncurses
    printf "\n${CYAN}Compiling ncurses...${NC}\n"
    step_compile_ncurses

    # Compile fbv
    printf "\n${CYAN}Compiling fbv...${NC}\n"
    step_compile_fbv

    # Add users
    printf "\n${CYAN}Adding users...${NC}\n"
    step_add_users
    
    # Configure network
    printf "\n${CYAN}Configuring network...${NC}\n"
    step_configure_network

    # Configure HTTP server
    printf "\n${CYAN}Configuring HTTP server...${NC}\n"
    step_configure_http_server

    # Configure SSH server
    printf "\n${CYAN}Configuring SSH server...${NC}\n"
    step_configure_ssh_server

    # Compile wiringPi
    printf "\n${CYAN}Compiling wiringPi...${NC}\n"
    step_compile_wiringPi

    # Copy images to pi
    printf "\n${CYAN}Copying images to pi...${NC}\n"
    step_copy_noot_noot

    # Copy target_pi to pi
    printf "\n${CYAN}Copying target_pi to pi...${NC}\n"
    step_copy_target_pi

    # Unmount device
    printf "\n${CYAN}Unmounting device...${NC}\n"
    step_unmount_device

    # End
    printf "\n${GREEN}Installation finished ! Press enter to continue...${NC}\n"
}

function mc_cleanup_files() {
    clear

    printf "${CYAN}Cleaning up build files...${NC}\n"
    rm -rf $WORKDIR/build/*

    printf "${CYAN}Cleaning up logs...${NC}\n"
    rm -rf $WORKDIR/logs/*

    printf "${CYAN}Cleaning up targets...${NC}\n"
    rm -rf $WORKDIR/targets/*

    printf "${GREEN}Done.${NC}\n"
}

# Print status of menu options functions :

function print_unpack_sources_status() {
    BUSYBOX_OK=0
    TOOLS_OK=0
    HELLO_WORLD_OK=0
    NCURSES_OK=0
    NCURSES_EXAMPLES_OK=0
    NCURSES_PROGRAMS_OK=0
    NCURSES_HELLO_OK=0
    FBV_OK=0
    JPEG_OK=0
    PNG_OK=0
    ZLIB_OK=0
    DROPBEAR_OK=0
    WIRINGPI_OK=0
    WIRINGPI_EXAMPLES_OK=0

    if [ -d $WORKDIR/build/busybox/ ]; then BUSYBOX_OK=1; fi
    if [ -d $WORKDIR/build/tools-master/ ]; then TOOLS_OK=1; fi
    if [ -d $WORKDIR/build/hello-world/ ]; then HELLO_WORLD_OK=1; fi
    if [ -d $WORKDIR/build/ncurses/ncurses/ ]; then NCURSES_OK=1; fi
    if [ -d $WORKDIR/build/ncurses/ncurses-examples/ ]; then NCURSES_EXAMPLES_OK=1; fi
    if [ -d $WORKDIR/build/ncurses/ncurses-programs/ ]; then NCURSES_PROGRAMS_OK=1; fi
    if [ -d $WORKDIR/build/ncurses/ncurses-hello/ ]; then NCURSES_HELLO_OK=1; fi
    if [ -d $WORKDIR/build/fbv/fbv/ ]; then FBV_OK=1; fi
    if [ -d $WORKDIR/build/fbv/jpeg/ ]; then JPEG_OK=1; fi
    if [ -d $WORKDIR/build/fbv/png/ ]; then PNG_OK=1; fi
    if [ -d $WORKDIR/build/fbv/zlib/ ]; then ZLIB_OK=1; fi
    if [ -d $WORKDIR/build/dropbear/ ]; then DROPBEAR_OK=1; fi
    if [ -d $WORKDIR/build/wiringPi/wiringPi/ ]; then WIRINGPI_OK=1; fi
    if [ -d $WORKDIR/build/wiringPi/wiringPi-examples/ ]; then WIRINGPI_EXAMPLES_OK=1; fi

    if [ $BUSYBOX_OK -eq 1 ] && [ $TOOLS_OK -eq 1 ] && [ $HELLO_WORLD_OK -eq 1 ] && [ $NCURSES_OK -eq 1 ] && [ $NCURSES_EXAMPLES_OK -eq 1 ] && [ $NCURSES_PROGRAMS_OK -eq 1 ] && [ $NCURSES_HELLO_OK -eq 1 ] && [ $FBV_OK -eq 1 ] && [ $JPEG_OK -eq 1 ] && [ $PNG_OK -eq 1 ] && [ $ZLIB_OK -eq 1 ] && [ $DROPBEAR_OK -eq 1 ] && [ $WIRINGPI_OK -eq 1 ] && [ $WIRINGPI_EXAMPLES_OK -eq 1 ]; then
        printf " ${GREEN}[Sources unpacked]${NC}"
    else
        printf " ${RED}[Sources not unpacked]${NC}"
    fi
}

function print_selected_device() {
    if [ -n "$DEVICE" ]; then
        printf " ${GREEN}[${DEVICE}]${NC}"
    else
        printf " ${RED}[No device selected]${NC}"
    fi
}

function print_selected_busybox_config_file() {
    if [ -n "$BUSYBOX_CONFIG_FILE" ]; then
        printf " ${GREEN}[${BUSYBOX_CONFIG_FILE}]${NC}"
    else
        printf " ${RED}[No config file selected]${NC}"
    fi
}

# --------------------------------------------------------------------------- #
#                               Util functions                                #
# --------------------------------------------------------------------------- #

# Function to ask a yes/no question, with a default answer DEFAULT_CHOICE,
# and store the answer in PROMPT_ANSWER.
function ask_prompt() {
    PROMPT_ANSWER=""

    while [ "$PROMPT_ANSWER" != "$YES" ] && [ "$PROMPT_ANSWER" != $NO ]; do
        # Present the question and show the default choice if there is one
        if [ "$DEFAULT_CHOICE" == "$YES" ]; then
            printf "${CYAN}${PROMPT} [Y/n] :${NC} "
        elif [ "$DEFAULT_CHOICE" == $NO ]; then
            printf "${CYAN}${PROMPT} [y/N] :${NC} "
        else
            printf "${CYAN}${PROMPT} [y/n] :${NC} "
        fi

        read PROMPT_ANSWER

        # If the user didn't answer and there is a default choice, use it
        if [ -z "$PROMPT_ANSWER" ] && [ -n "$DEFAULT_CHOICE" ]; then
            PROMPT_ANSWER="$DEFAULT_CHOICE"
        fi

        # Convert the answer to lowercase
        PROMPT_ANSWER=$(echo "$PROMPT_ANSWER" | awk '{print tolower($0)}')
    done
}

function wait_enter() {
    read -p "Press enter to continue..."
}

function show_devices() {
    DEV_SEARCH="sd"

    # df -h
    printf "${CYAN}\nDevices starting with \"/dev/$DEV_SEARCH\" :${NC}\n"
    df -h | grep -e "/dev/$DEV_SEARCH" -e "Filesystem"
    wait_enter

    # fdisk -l
    printf "${CYAN}\nInformations about partitions of devices starting with \"/dev/$DEV_SEARCH\" :${NC}\n"
    sudo fdisk -l /dev/${DEV_SEARCH}*
    wait_enter

    # dmesg
    printf "${CYAN}\nLast messages of device detection (containing \"$DEV_SEARCH\") :${NC}\n"
    dmesg | grep sd | tail
}

# --------------------------------------------------------------------------- #
#                           Install step functions                            #
# --------------------------------------------------------------------------- #

function step_init() {
    # Create target directories in build/ folder
    sudo mkdir -p $TARGET_PC
    sudo mkdir -p $TARGET_PI
}

function step_unmount_device() {
    # Unmount all partitions of the device
    ls ${DEVICE}?* | xargs -n1 umount -l
}

function step_delete_partitions() {
    sfdisk --delete ${DEVICE}
}

function step_create_partitions() {
    (
    printf "n\n" # Add a new partition
    printf "p\n" # Primary partition
    printf "1\n" # Partition number
    printf "\n"  # First sector (Accept default: 1)
    printf "+100M\n" # Last sector 
    printf "n\n" # Add a new partition
    printf "p\n" # Primary partition
    printf "2\n" # Partition number
    printf "\n"  # First sector (Accept default: 1)
    printf "+200M\n" # Last sector 
    printf "t\n" # Change partition type
    printf "1\n" # First partition
    printf "c\n" # W95 FAT32 (LBA)
    printf "t\n" # Change partition type
    printf "2\n" # Second partition
    printf "83\n" # Linux
    printf "w\n" # Write changes
    ) | sudo fdisk ${DEVICE}
}

function step_format_partitions() {
    # Format the first partition (boot) as fat32
    sudo mkfs.vfat ${DEVICE}1

    # Format the first partition (root) as ext4
    sudo mkfs.ext4 ${DEVICE}2
}

function step_mount_partitions() {
    # Mount boot partition
    sudo mkdir -p $BOOT_DIR/
    sudo mount ${DEVICE}1 $BOOT_DIR/

    # Mount root partition
    sudo mkdir -p $ROOT_DIR/
    sudo mount ${DEVICE}2 $ROOT_DIR/
}

function step_copy_boot_files() {
    sudo cp -r $WORKDIR/data/boot_rpi/* $BOOT_DIR/
}

function step_create_fs() {
    sudo mkdir -p $ROOT_DIR/sbin/
    sudo mkdir -p $ROOT_DIR/bin/
    sudo mkdir -p $ROOT_DIR/usr/
    sudo mkdir -p $ROOT_DIR/lib/
    sudo mkdir -p $ROOT_DIR/dev/
    sudo mkdir -p $ROOT_DIR/proc/
    sudo mkdir -p $ROOT_DIR/sys/
    sudo mkdir -p $ROOT_DIR/etc/
}

function step_install_busybox() {
    # (Config file is already in build/busybox/.config)
    cd $WORKDIR/build/busybox/

    # Make and install busybox
    sudo apt-get update
    sudo apt-get install -y libncurses-dev makedev
    make -j9 V=1 CROSS_COMPILE=$CROSS_PREFIX
    make V=1 CROSS_COMPILE=$CROSS_PREFIX CONFIG_PREFIX=$ROOT_DIR install
}

function step_copy_busybox_dynamic_libs {
    # Copy dynamic libraries needed by busybox
    cd $WORKDIR/build/busybox/
    ldd busybox | grep lib/ | tr -d ' ' | cut -d'>' -f2 | cut -d'(' -f1 | xargs -n 1 -I {} cp {} $ROOT_DIR/lib/
}

function step_copy_rcS() {
    sudo mkdir -p $ROOT_DIR/etc/init.d/
    sudo cp $WORKDIR/data/rcS $ROOT_DIR/etc/init.d/rcS
    sudo chmod ug+x $ROOT_DIR/etc/init.d/rcS # Make it executable
}

function step_copy_inittab() {
    sudo cp $WORKDIR/data/inittab $ROOT_DIR/etc/inittab
}

function step_copy_kmap() {
    sudo cp $WORKDIR/data/azerty.kmap $ROOT_DIR/etc/
}

function step_hello_world_program() {
    cd $WORKDIR/build/hello-world/

    # Make hello_world program for PC
    make hello_pc
    sudo mkdir -p $TARGET_PC/usr/bin/
    sudo mv hello_pc $TARGET_PC/usr/bin/

    # Make hello_world program for PI
    CC=$CCC make hello_pi
    sudo mkdir -p $TARGET_PI/usr/bin/
    sudo mv hello_pi $TARGET_PI/usr/bin/
}

function step_copy_libs() {
    sudo cp /$($CCC -print-sysroot)/lib/arm-linux-gnueabihf/* $ROOT_DIR/lib
}

function step_create_targets() {
    # Create compilation tools target symlinks
    sudo mkdir -p $WORKDIR/targets/target_rootfs/
    ln -s $($CCC -print-sysroot)/lib/arm-linux-gnueabihf/ $WORKDIR/targets/target_rootfs/
}

function step_compile_ncurses() {
    cd $WORKDIR/build/ncurses/

    # Compile ncurses for pc
    cd ncurses/
    ./configure --prefix=$TARGET_PC --with-shared
    make -j9
    make install

    # Compile ncurses for pi
    CC=$CCC CXX=$CXX \
        ./configure \
            --prefix=$TARGET_PI \
            --host=x86_64-build_unknown-linux-gnu \
            --target=arm-linux-gnueabihf  \
            --with-shared \
            --disable-stripping
    make -j9
    make install
    
    # Compile Ncurses "hello world" test program
    cd ../ncurses-hello/
    CC=$CCC TARGET_PC=$TARGET_PC TARGET_PI=$TARGET_PI make
    sudo mkdir -p $TARGET_PC/usr/bin/
    sudo mkdir -p $TARGET_PI/usr/bin/
    mv ncurses_hello_pc $TARGET_PC/usr/bin/
    mv ncurses_hello_pi $TARGET_PI/usr/bin/

    # Compile ncurses_example for PC
    cd ../ncurses-examples/
    make clean
    CC=gcc ./configure --prefix=$TARGET_PC
    make -j9
    make install

    # Compile ncurses_examples for PI
    make clean
    CC=$CCC LDFLAGS=-L$TARGET_PI/lib CPPFLAGS="-I$TARGET_PI/include/ncurses -I$TARGET_PI/include" \
        ./configure \
            --prefix=$TARGET_PI \
            --host=x86_64-build_unknown-linux-gnu \
            --target=arm-linux-gnueabihf \
            --disable-stripping
    make -j9
    make install

    # Compile ncurses_programs for PC
    cd ../ncurses-programs/
    cp $WORKDIR/data/makefiles/MakefileNcursesPrograms_pc ./JustForFun/Makefile
    TARGET_PC=$TARGET_PC CC=gcc make -j9
    mv ./demo/exe/* $TARGET_PC/bin/
    make clean

    # Compile ncurses_programs for PI
    cp $WORKDIR/data/makefiles/MakefileNcursesPrograms_pi ./JustForFun/Makefile
    TARGET_PI=$TARGET_PI CC=$CCC make -j9
    mv ./demo/exe/* $TARGET_PI/bin/
    make clean

    # Resolve "Error: opening terminal linux" error by setting environment variables in /etc/profile
    printf "export TERM=linux
        export TERMINFO=/lib/terminfo
        " >> /$ROOT_DIR/etc/profile
}

function step_compile_fbv() {
    cd $WORKDIR/build/fbv/

    # Compile libjpeg
    cd jpeg/
    make clean
    CC=$CCC LDFLAGS=-L$TARGET_PI/lib CPPFLAGS="-I$TARGET_PI/include/ncurses -I$TARGET_PI/include" \
        ./configure \
            --prefix=$TARGET_PI \
            --host=x86_64-build_unknown-linux-gnu \
            --target=arm-linux-gnueabihf
    make -j9
    make install

    # Compile zlib for libpng
    cd ../zlib/
    make clean
    CROSS_PREFIX=$CROSS_PREFIX CC=$CCC CXX=$CXX \
        ./configure --prefix=$TARGET_PI
    make -j9
    make install

    # Compile libpng
    cd ../png/
    make clean
    CC=$CCC LDFLAGS=-L$TARGET_PI/lib CPPFLAGS="-I$TARGET_PI/include/ncurses -I$TARGET_PI/include" \
        ./configure \
            --prefix=$TARGET_PI \
            --host=x86_64-build_unknown-linux-gnu \
            --target=arm-linux-gnueabihf \
            --enable-shared
    make -j9
    make install

    # Compile fbv
    cd ../fbv/
    cp $WORKDIR/data/makefiles/MakefileFBV_pi ./Makefile
    make clean
    ./configure --prefix=$TARGET_PI
    CC=$CXX TARGET_PI=$TARGET_PI make -j9
    make install

    sudo chmod u+s $TARGET_PI/bin/fbv
}

function step_copy_noot_noot() {
    # Copy example "Tux" images to the Raspberry Pi
    sudo mkdir -p $ROOT_DIR/usr/share/images/
    sudo cp $WORKDIR/data/images/* $ROOT_DIR/usr/share/images/
}

function step_add_users() {
    sudo mkdir -p $ROOT_DIR/etc/

    # Create the passwd and group files (passwords are already encrypted)
    printf "root::0:0:Super User:/:/bin/sh
        noe:UYS9bDrVDntaA:1000:1000:Linux User,,,:/home/noe:/bin/sh
        math:YacOIYv67JEpU:1001:1001:Linux User,,,:/home/math:/bin/sh
        " > $ROOT_DIR/etc/passwd # noe:cisco, math:cisco
    printf "root:x:0:\nnoe:x:1000:\nmath:x:1001:\n" > $ROOT_DIR/etc/group

    # User home directories with the right permissions
    sudo mkdir -p $ROOT_DIR/home/noe/
    sudo mkdir -p $ROOT_DIR/home/math/
    sudo chown -R 1000:1000 $ROOT_DIR/home/noe/
    sudo chown -R 1001:1001 $ROOT_DIR/home/math/
    sudo chmod -R 750 $ROOT_DIR/home/noe/
    sudo chmod -R 750 $ROOT_DIR/home/math/
}

function step_configure_network() {
    # Copy the network udhcp configuration files from BusyBox examples
    sudo mkdir -p $ROOT_DIR/usr/share/udhcpc/
    sudo cp $WORKDIR/build/busybox/examples/udhcp/simple.script $ROOT_DIR/usr/share/udhcpc/default.script
    sudo chmod +x $ROOT_DIR/usr/share/udhcpc/default.script # Make it executable
}

function step_configure_http_server() {
    # Add the index.html file in /var/www/html/, which will be served by the http server
    sudo mkdir -p $ROOT_DIR/var/www/html/
    sudo echo "<h1>Hello World</h1>" > $ROOT_DIR/var/www/html/index.html
}

function step_configure_ssh_server() {
    sudo mkdir -p $ROOT_DIR/etc/dropbear/ # To store the host keys

    # Configure, compile & install dropbear in static mode
    cd $WORKDIR/build/dropbear/
    sudo CC=$CCC CXX=$CXX CPFLAGS=-I$TARGET_PI/include LDFLAGS=-L$TARGET_PI/lib CPPFLAGS=-I$TARGET_PI/include \
        ./configure \
            --prefix=$TARGET_PI \
            --enable-static \
            --build=x86_64-build_unknown-linux-gnu \
            --host=arm-linux-gnueabihf \
            --with-zlib=$TARGET_PI/lib/
    sudo make
    sudo make PROGRAMS="dropbear dropbearkey scp" STATIC=1 install
}

function step_compile_wiringPi() {
    # Create target_wpi/ directory
    TARGET_WPI=$WORKDIR/build/target_wpi/
    sudo mkdir -p $TARGET_WPI $TARGET_WPI/lib/ $TARGET_WPI/include/ $TARGET_WPI/bin/

    cd $WORKDIR/build/wiringPi/wiringPi/

    # Compile libWiringPi
    cd wiringPi/
    cp $WORKDIR/data/makefiles/MakefileWiringPi_pi ./Makefile
    make clean
    PREFIX=$TARGET_WPI CC=$CCC LDFLAGS=-L/$($CCC -print-sysroot)/lib/arm-linux-gnueabihf/ \
        make V=1
    make V=1 install
    cp libwiringPi.so* $TARGET_WPI/lib/
    cp *.h $TARGET_WPI/include/

    # Compile libWiringPiDev
    cd ../devLib/
    cp $WORKDIR/data/makefiles/MakefileDevLib_pi ./Makefile
    make clean
    PREFIX=$TARGET_WPI CC=$CCC CPFLAGS=-I$TARGET_WPI/include LDFLAGS="-L/$($CCC -print-sysroot)/lib/arm-linux-gnueabihf/ -L$TARGET_WPI/lib" \
        make V=1
    make V=1 install
    cp libwiringPiDev.so* $TARGET_WPI/lib/
    cp *.h $TARGET_WPI/include/
   
    # Symlinks for wiringPi
    cd $TARGET_WPI/lib/
    ln -s libwiringPi.so.2.50 libwiringPi.so
    ln -s libwiringPiDev.so.2.50 libwiringPiDev.so

    # Compile gpio
    cd $WORKDIR/build/wiringPi/wiringPi/gpio/
    cp $WORKDIR/data/makefiles/MakefileGPIO_pi ./Makefile
    make clean
    PREFIX=$TARGET_WPI CC=$CCC CPFLAGS=-I$TARGET_WPI/include LDFLAGS="-L/$($CCC -print-sysroot)/lib/arm-linux-gnueabihf/ -L$TARGET_WPI/lib" \
        make V=1
    cp gpio $TARGET_WPI/bin/
    
    # Example programs
    cd $WORKDIR/build/wiringPi/wiringPi-examples/

    # Diode example
    make clean
    PREFIX=$TARGET_WPI CC=$CCC CPFLAGS=-I$TARGET_WPI/include LDFLAGS="-L/$($CCC -print-sysroot)/lib/arm-linux-gnueabihf/ -L$TARGET_WPI/lib" \
        make

    # Copy target_wpi/ directory to pi
    sudo cp -r $TARGET_WPI/* $ROOT_DIR
}

function step_copy_target_pi() {
    sudo cp -r $TARGET_PI/* $ROOT_DIR
}

# --------------------------------------------------------------------------- #
#                                Main Program                                 #
# --------------------------------------------------------------------------- #

# Check if root
if [ "$EUID" -ne 0 ]; then
    printf "${RED}Please run this script as root.\n${NC}"
    exit 1
fi

# Create needed directory
mkdir -p $WORKDIR/build/
mkdir -p $WORKDIR/logs/
mkdir -p $WORKDIR/targets/

# Show menu
menu
