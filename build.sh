#!/bin/bash

set -e

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--target)            BUILD_TARGET="$2";      shift; shift ;;
    -bv|--binutils-version) BINUTILS_VERSION="$2";  shift; shift ;;
    -gv|--gcc-version)      GCC_VERSION="$2";       shift; shift ;;
    -dv|--gdb-version)      GDB_VERSION="$2";       shift; shift ;;
    *)                                              shift ;;          
esac
done

BUILD_DIR="$HOME/build-${BUILD_TARGET}"
export PATH="/opt/mxe/usr/bin:$BUILD_DIR/linux/output/bin:$BUILD_DIR/windows/output/bin:$PATH"

echo "BUILD_TARGET     = ${BUILD_TARGET}"
echo "BUILD_DIR        = ${BUILD_DIR}"
echo "BINUTILS_VERSION = ${BINUTILS_VERSION}"
echo "GCC_VERSION      = ${GCC_VERSION}"
echo "GDB_VERSION      = ${GDB_VERSION}"
echo "PATH             = ${PATH}"

function main {
    installPackages
    installMXE
    sudo rm -rf /var/lib/apt/lists /opt/mxe/.ccache /opt/mxe/pkg
    downloadSources
    compileAll "linux"
    compileAll "windows"
    if [[ -d "$BUILD_DIR/windows/output" ]]; then
        cd $BUILD_DIR/windows/output
        zip -r "${BUILD_DIR}/${BUILD_TARGET}-tools-windows.zip" *
    fi
    if [[ -d "$BUILD_DIR/linux/output" ]]; then
        cd $BUILD_DIR/linux/output
        zip -r "${BUILD_DIR}/${BUILD_TARGET}-tools-linux.zip" *
    fi
    echo -e "\e[92mZipped everything to $BUILD_DIR/${BUILD_TARGET}-tools-[windows | linux].zip\e[39m"
}
function installPackages {
    pkgList=(
        git
        autoconf
        automake
        autopoint
        autotools-dev
        bash
        curl
        bison
        bzip2
        flex
        gettext
        git
        g++
        gperf
        intltool
        libffi-dev
        libgdk-pixbuf2.0-dev
        libgmp-dev
        libtool
        libltdl-dev
        libssl-dev
        libxml-parser-perl
        libipt-dev
        libdebuginfod-dev
        libmpc-dev
        patchutils
        bc
        zlib1g-dev
        libmpfr-dev
        gawk 
        build-essential
        make
        sudo
        openssl
        p7zip-full
        patch
        ninja-build
        cmake
        libglib2.0-dev
        perl
        pkg-config
        ruby
        scons
        sed
        unzip
        wget
        xz-utils
        libtool-bin
        texinfo
        g++-multilib
        lzip
        babeltrace
        libexpat-dev
        python3 python3-dev python-is-python3 python3-mako python3-pip
        )
    echoColor "Installing packages"
    sudo apt-get update -y -qq
    for pkg in ${pkgList[@]}; do
        sudo -E DEBIAN_FRONTEND=noninteractive apt-get -qq install $pkg -y
    done
}

function installMXE {
    echoColor "Installing MXE"
    if [ ! -d "/opt/mxe/usr/bin" ]; then
        echoColor "    Cloning MXE and compiling mingw32.static GCC"
        cd /opt
        sudo -E git clone https://github.com/mxe/mxe.git
        cd mxe
        sudo make -j12 gcc gmp
    else
       echoColor "    MXE is already installed. You'd better make sure that you've previously made MXE's gcc! (/opt/mxe/usr/bin/i686-w64-mingw32.static-gcc)"
    fi
}

function downloadSources {
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    echoColor "Downloading all sources"
    downloadAndExtract "binutils" $BINUTILS_VERSION
    downloadAndExtract "gcc" $GCC_VERSION "http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
    echoColor "        Downloading GCC prerequisites"
    cd ./linux/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    cd $BUILD_DIR
    cd ./windows/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    cd $BUILD_DIR
    downloadAndExtract "gdb" $GDB_VERSION
}

function downloadAndExtract {
    name=$1
    version=$2
    override=$3
    
    echoColor "    Processing $name"
    if [ ! -f $name-$version.tar.gz ]; then
        echoColor "        Downloading $name-$version.tar.gz"
        if [ -z $3 ]; then
            wget -q http://ftp.gnu.org/gnu/$name/$name-$version.tar.gz
        else
            wget -q $override
        fi
    fi

    mkdir -p linux
    cd linux
    if [ ! -d $name-$version ]; then
        echoColor "        [linux]   Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi
    cd ..
    mkdir -p windows
    cd windows
    if [ ! -d $name-$version ]; then
        echoColor "        [windows] Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi
    cd ..
}

function compileAll {
    echoColor "Compiling all $1"
    cd $1
    mkdir -p output
    compileBinutils $1
    compileGCC $1
    compileGDB $1
    cd ..
}

function compileBinutils {    
    echoColor "    Compiling binutils [$1]"
    mkdir -p build-binutils-$BINUTILS_VERSION
    cd build-binutils-$BINUTILS_VERSION
    configureArgs="--target=$BUILD_TARGET --with-sysroot --disable-nls --disable-werror --prefix=$BUILD_DIR/$1/output"
    if [[ $BUILD_TARGET == "i386-elf" || $BUILD_TARGET == "i686-elf" || $BUILD_TARGET == "x86_64-elf" ]]; then
        configureArgs="--enable-targets=x86_64-pep $configureArgs"
    fi
    if [ $BUILD_TARGET == "aarch64-elf" ]; then
        configureArgs="--enable-targets=aarch64-pe $configureArgs"
    fi
    if [ $BUILD_TARGET == "arm-none-eabi" ]; then
        configureArgs="--enable-targets=arm-pe $configureArgs"
    fi
    if [ $1 == "windows" ]; then
        configureArgs="--host=i686-w64-mingw32.static $configureArgs"
    fi
    ../binutils-$BINUTILS_VERSION/configure $configureArgs
    make -j12
    sudo make install
    cd ..
}

function compileGCC {
    echoColor "    Compiling gcc [$1]"
    mkdir -p build-gcc-$GCC_VERSION
    cd build-gcc-$GCC_VERSION
    configureArgs="--target=$BUILD_TARGET --disable-nls --enable-languages=c,c++ --without-headers --prefix=$BUILD_DIR/$1/output"
    if [ $1 == "windows" ]; then
        configureArgs="--host=i686-w64-mingw32.static $configureArgs"
    fi
    if [[ $BUILD_TARGET == "x86_64-elf" ]]; then
        echoColor "        Installing config/i386/t-x86_64-elf"
        echo -e "# Add libgcc multilib variant without red-zone requirement\n\nMULTILIB_OPTIONS += mno-red-zone\nMULTILIB_DIRNAMES += no-red-zone" > ../gcc-$GCC_VERSION/gcc/config/i386/t-x86_64-elf
        echoColor "        Patching gcc/config.gcc"
        sed -i '/x86_64-\*-elf\*)/a \\ttmake_file="${tmake_file} i386/t-x86_64-elf" # include the new multilib configuration' ../gcc-$GCC_VERSION/gcc/config.gcc
    fi
    ../gcc-$GCC_VERSION/configure $configureArgs
    make -j12 all-gcc
    sudo make -j12 install-gcc
    make -j12 all-target-libgcc
    sudo make install-target-libgcc
    if [[ $BUILD_TARGET == "x86_64-elf" ]]; then
        if [ $1 == "windows" ]; then
            cd "${BUILD_TARGET}/no-red-zone/libgcc"
            sudo make install
            cd ../../..
        fi
        if [[ ! -d "../output/lib/gcc/x86_64-elf/$GCC_VERSION/no-red-zone" ]]; then
            echoError "ERROR: no-red-zone was not created. x64 patching failed"
            exit 1
        else
            echoColor "            Successfully compiled for no-red-zone"
        fi
    fi
    cd ..
}

function compileGDB {
    echoColor "    Compiling gdb [$1]"
    configureArgs="--target=$BUILD_TARGET --disable-nls --disable-werror --prefix=$BUILD_DIR/$1/output"
    if [ $1 == "windows" ]; then
        configureArgs="--host=i686-w64-mingw32.static $configureArgs"
    fi
    mkdir -p build-gdb-$GDB_VERSION
    cd build-gdb-$GDB_VERSION
    ../gdb-$GDB_VERSION/configure $configureArgs
    make -j12
    sudo make install
    cd ..
}

function echoColor {
    echo -e "\e[96m$1\e[39m"
}

function echoError {
    echo -e "\e[31m$1\e[39m"
}

main
