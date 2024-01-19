#!/usr/bin/env bash

set -e
set -x

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

export PATH="/opt/mxe/usr/bin:$HOME/linux-$BUILD_TARGET/output/bin:$HOME/windows-$BUILD_TARGET/output/bin:$HOME/macos-$BUILD_TARGET/output/bin:$PATH"

ON_MAC=false
if [[ "$OSTYPE" == "darwin"* ]]; then
ON_MAC=true
fi

echo "BUILD_TARGET     = ${BUILD_TARGET}"
echo "BINUTILS_VERSION = ${BINUTILS_VERSION}"
echo "GCC_VERSION      = ${GCC_VERSION}"
echo "GDB_VERSION      = ${GDB_VERSION}"
echo "PATH             = ${PATH}"

function main {
    if [ $ON_MAC == true ]; then
        installPackagesMac
    else
        installPackages
        installMXE
    fi

    downloadSources
    if [ $ON_MAC == true ]; then
    compileAll "macos"
    else
        compileAll "linux"
        compileAll "windows"
    fi
    echo -e "\e[92mZipped everything to $HOME/${BUILD_TARGET}-tools-[windows | linux | macos].zip\e[39m"
}

function installPackagesMac {
    brew update
    brew upgrade
#    brew install --force coreutils bzip2 flex gperf intltool gdk-pixbuf pcre openssl libtool lzip make p7zip gnu-sed unzip libmpc isl gmp mpfr guile expat zlib gawk gzip
}

function installPackages {
    echoColor "Installing packages"
    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo -E DEBIAN_FRONTEND=noninteractive apt-get install -y autopoint g++-multilib gettext gperf libtool-bin intltool libc6-dev-i386 libgdk-pixbuf2.0-dev libltdl-dev libgl-dev libpcre3-dev libxml-parser-perl lzip python3-distutils python3-mako  python3-pkg-resources sed build-essential libmpc-dev libisl-dev libgmp-dev libgmp10 libmpfr-dev libmpfr6 guile-3.0-dev libexpat1-dev liblzma-dev zlib1g-dev
}

function installMXE {
    echoColor "Installing MXE"
    if [ ! -d "/opt/mxe/usr/bin" ]; then
        echoColor "    Cloning MXE and compiling mingw32.static GCC"
        cd /opt
        sudo -E git clone https://github.com/mxe/mxe.git
        cd mxe
        sudo make -j12 gcc gmp
        sudo rm -rf .ccache plugins src ext pkg log tools docs .github
        sudo find /opt/mxe
    else
       echoColor "    MXE is already installed. You'd better make sure that you've previously made MXE's gcc! (/opt/mxe/usr/bin/i686-w64-mingw32.static-gcc)"
    fi
}

function downloadSources {
    cd $HOME
    echoColor "Downloading all sources"
    downloadAndExtract "binutils" $BINUTILS_VERSION
    downloadAndExtract "gcc" $GCC_VERSION "http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
    downloadAndExtract "gdb" $GDB_VERSION
    echoColor "        Downloading GCC prerequisites"
    if [ $ON_MAC == true ]; then
    cd ./macos-$BUILD_TARGET/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    else
    cd ./linux-$BUILD_TARGET/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    cd ../..
    cd ./windows-$BUILD_TARGET/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    fi
    cd ../..
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

    if [ $ON_MAC == true ]; then
    mkdir -p macos-$BUILD_TARGET
    cd macos-$BUILD_TARGET
    if [ ! -d $name-$version ]; then
        echoColor "        [macos]   Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi
    else
    mkdir -p linux-$BUILD_TARGET
    cd linux-$BUILD_TARGET
    if [ ! -d $name-$version ]; then
        echoColor "        [linux]   Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi
    cd ..
    mkdir -p windows-$BUILD_TARGET
    cd windows-$BUILD_TARGET
    if [ ! -d $name-$version ]; then
        echoColor "        [windows] Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi

    fi
    cd ..
}

function compileAll {
    # $1: platform
    echoColor "Compiling all $1"
    cd $HOME/$1-$BUILD_TARGET
    mkdir -p output

    compile binutils $BINUTILS_VERSION $1
    compile gcc $GCC_VERSION $1
    compile gdb $GDB_VERSION $1
    cd ..
    if [[ -d "$HOME/$1-$BUILD_TARGET/output" ]]; then
        cd $HOME/$1-$BUILD_TARGET/output
        zip -r "$HOME/${BUILD_TARGET}-tools-$1.zip" *
    fi
    rm -rf $HOME/$1-$BUILD_TARGET
}

function compile {
    name=$1
    version=$2
    platform=$3
    echoColor "    Compiling $name [$platform-$BUILD_TARGET]"
    mkdir -p build-$name-$version
    cd build-$name-$version
    configureArgs="--enable-silent-rules --target=$BUILD_TARGET --disable-nls --disable-werror --prefix=$HOME/$platform-$BUILD_TARGET/output"
   
    if [ $name == "gcc" ]; then
    configureArgs="--enable-languages=c,c++ --without-headers $configureArgs"
    else
    configureArgs="--with-sysroot $configureArgs"
    fi

    if [ $ON_MAC == true ]; then
    SED=gsed
    else
    SED=sed
    fi
    
    if [ $name == "binutils" ]; then
    if [[ $BUILD_TARGET == "i386-elf" || $BUILD_TARGET == "i686-elf" || $BUILD_TARGET == "x86_64-elf" ]]; then
        configureArgs="--enable-targets=x86_64-pep $configureArgs"
    fi
    if [ $BUILD_TARGET == "aarch64-elf" ]; then
        configureArgs="--enable-targets=aarch64-pe $configureArgs"
    fi
    if [ $BUILD_TARGET == "arm-none-eabi" ]; then
        configureArgs="--enable-targets=arm-pe $configureArgs"
    fi
    fi

    if [ $platform == "windows" ]; then
        configureArgs="--host=i686-w64-mingw32.static $configureArgs"
    fi
    
    if [[ $name == "gcc" && $BUILD_TARGET == "x86_64-elf" ]]; then
        echoColor "        Installing config/i386/t-x86_64-elf"
        echo -e "MULTILIB_OPTIONS += mno-red-zone\nMULTILIB_DIRNAMES += no-red-zone" > ../gcc-$GCC_VERSION/gcc/config/i386/t-x86_64-elf
        echoColor "        Patching gcc/config.gcc"
        $SED -i '/x86_64-\*-elf\*)/a \\ttmake_file="${tmake_file} i386/t-x86_64-elf" # include the new multilib configuration' ../gcc-$GCC_VERSION/gcc/config.gcc
    fi

    ../$name-$version/configure $configureArgs
    if [ $name == "gcc" ]; then
        make -j12 all-gcc
    else
        make -j12
    fi

    if [[ $name == "gcc" && $BUILD_TARGET == "x86_64-elf" ]]; then
        make -j12 all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=large -mno-red-zone'
    else
        make -j12 all-target-libgcc
    fi

    if [[ $name == "gcc" ]]; then
    sudo make -j12 install-gcc
    sudo make install-target-libgcc
    else
    sudo make install
    fi
    
    if [[ $name == "gcc" && $BUILD_TARGET == "x86_64-elf" ]]; then
        if [ $platform == "windows" ]; then
            cd "${BUILD_TARGET}/no-red-zone/libgcc"
            sudo make install
            cd ../../..
        fi
        if [[ ! -d "../output/lib/gcc/x86_64-elf/$version/no-red-zone" ]]; then
            echoError "ERROR: no-red-zone was not created. x64 patching failed"
            exit 1
        else
            echoColor "            Successfully compiled for no-red-zone"
        fi
    fi
    cd ..
}

function echoColor {
    echo -e "\e[96m$1\e[39m"
}

function echoError {
    echo -e "\e[31m$1\e[39m"
}

main
