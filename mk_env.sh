export PATH_CC=$(pwd)/build/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
export CROSS_PREFIX=$PATH_CC/arm-linux-gnueabihf-
export CCC=$CROSS_PREFIX"gcc"
export CXX=$CROSS_PREFIX"g++"
export TARGET_PC=$(pwd)/build/target_pc
export TARGET_PI=$(pwd)/build/target_pi
