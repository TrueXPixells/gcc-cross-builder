#!/usr/bin/env bash

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

ON_MAC=false
if [[ "$OSTYPE" == "darwin"* ]]; then
ON_MAC=true
fi

GCC_VERSION="13.2.0"
BINUTILS_VERSION="2.42"
GDB_VERSION="14.2"

echo "BUILD_TARGET     = ${BUILD_TARGET}"
echo "BINUTILS_VERSION = ${BINUTILS_VERSION}"
echo "GCC_VERSION      = ${GCC_VERSION}"
echo "GDB_VERSION      = ${GDB_VERSION}"
echo "PATH             = ${PATH}"

brew-path() { brew info $1 | head -n3 | tail -n1 | cut -d' ' -f1; }

function main {
    if [ $ON_MAC == true ]; then
        installPackagesMac
    else
        installPackages
    fi

    downloadSources $BUILD_TARGET
    if [ $ON_MAC == true ]; then
        compileAll "macos" $BUILD_TARGET
    else
        compileAll "linux" $BUILD_TARGET
        #installMXE
        #compileAll "windows" $BUILD_TARGET
    fi
    echo -e "\e[92mZipped everything to $HOME/${BUILD_TARGET}-tools-[windows | linux | macos].zip\e[39m"
}

function installPackagesMac {
#    brew update
#    brew upgrade
#    brew install --force coreutils bzip2 flex gperf intltool gdk-pixbuf pcre openssl libtool lzip make p7zip gnu-sed unzip libmpc isl gmp mpfr guile expat zlib gawk gzip
    brew install gsed guile gmp mpfr mpc
    PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
}

function installPackages {
    echoColor "Installing packages"
    sudo apt-get update -y
    sudo apt-get upgrade -y
    #sudo -E DEBIAN_FRONTEND=noninteractive apt-get install -y \
    #autopoint \
    #g++-multilib \
    #gettext \
    #gperf \
    #libtool-bin \
    #intltool \
    #libc6-dev-i386 \
    #libgdk-pixbuf2.0-dev \
    #libltdl-dev \
    #libgl-dev \
    #libpcre3-dev \
    #libxml-parser-perl \
    #lzip \
    #python3-distutils \
    #python3-mako \
    #python3-pkg-resources \
    #sed \
    #build-essential \
    #libmpc-dev \
    #libisl-dev \
    #libgmp-dev \
    #libmpfr-dev \
    #guile-3.0-dev \
    #libexpat1-dev \
    #liblzma-dev \
    #zlib1g-dev

        pkgList=(
        libgl-dev
        libpcre3-dev
        python3-distutils
        python3-pkg-resources
        build-essential
        libmpc-dev
        libisl-dev
        libmpfr-dev
        guile-3.0-dev
        libexpat1-dev
        liblzma-dev
        zlib1g-dev

        git
        autoconf
        automake
        autopoint
        bash
        bison
        bzip2
        flex
        gettext
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
        make
        python3-mako
        openssl
        p7zip-full
        patch
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
        python3 python-is-python3
        )

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
        sudo make -j8 gcc gmp
        sudo rm -rf .ccache plugins src ext pkg log tools docs .github
        sudo find /opt/mxe
        PATH="/opt/mxe/usr/bin:$PATH"
    else
       echoColor "    MXE is already installed. You'd better make sure that you've previously made MXE's gcc! (/opt/mxe/usr/bin/i686-w64-mingw32.static-gcc)"
    fi
}

function downloadSources {
    target=$1
    cd $HOME
    echoColor "Downloading all sources"
    downloadAndExtract "binutils" $target $BINUTILS_VERSION
    downloadAndExtract "gcc" $target $GCC_VERSION "http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
    downloadAndExtract "gdb" $target $GDB_VERSION
    echoColor "        Downloading GCC prerequisites"
    if [ $ON_MAC == true ]; then
    cd ./macos-$target/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    else
    cd ./linux-$target/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    cd ../..
    cd ./windows-$target/gcc-$GCC_VERSION
    ./contrib/download_prerequisites
    fi
    cd ../..
}

function downloadAndExtract {
    name=$1
    target=$2
    version=$3
    override=$4
    
    echoColor "    Processing $name"
    if [ ! -f $name-$version.tar.gz ]; then
        echoColor "        Downloading $name-$version.tar.gz"
        if [ -z $override ]; then
            wget -q http://ftp.gnu.org/gnu/$name/$name-$version.tar.gz
        else
            wget -q $override
        fi
    fi

    if [ $ON_MAC == true ]; then
    mkdir -p macos-$target
    cd macos-$target
    if [ ! -d $name-$version ]; then
        echoColor "        [macos]   Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi

    else
    
    mkdir -p linux-$target
    cd linux-$target
    if [ ! -d $name-$version ]; then
        echoColor "        [linux]   Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi
    cd ..
    mkdir -p windows-$target
    cd windows-$target
    if [ ! -d $name-$version ]; then
        echoColor "        [windows] Extracting $name-$version.tar.gz"
        tar -xf ../$name-$version.tar.gz
    fi

    fi
    cd ..
}

function compileAll {
    platform=$1
    target=$2
    echoColor "Compiling all $platform"
    cd $HOME/$platform-$target
    mkdir -p output
    export PATH="$HOME/$platform-$target/output/bin:$PATH"
    compile binutils $BINUTILS_VERSION $platform $target
    compile gcc $GCC_VERSION $platform $target
    compile gdb $GDB_VERSION $platform $target
    cd ..
    if [[ -d "$HOME/$platform-$target/output" ]]; then
        cd $HOME/$platform-$target/output
        zip -r "$HOME/$target-tools-$1.zip" *
    fi
#    sudo rm -rf $HOME/$platform-$target
}

function compile {
    name=$1
    version=$2
    platform=$3
    target=$4
    echoColor "    Compiling $name [$platform-$target]"
    mkdir -p build-$name-$version
    cd build-$name-$version
    configureArgs="--target=$target --disable-nls --prefix=$HOME/$platform-$target/output"
   
    if [ $name == "gcc" ]; then
    configureArgs="--enable-languages=c,c++ --without-headers $configureArgs"
    else
    configureArgs="--with-sysroot --disable-werror $configureArgs"
    fi
    
    if [ $name == "binutilsx" ]; then
    if [[ $target == "i386-elf" || $target == "i686-elf" || $target == "x86_64-elf" ]]; then
        configureArgs="--enable-targets=x86_64-pep $configureArgs"
    fi
    if [ $target == "aarch64-elf" ]; then
        configureArgs="--enable-targets=aarch64-pe $configureArgs"
    fi
    if [ $target == "arm-none-eabi" ]; then
        configureArgs="--enable-targets=arm-pe $configureArgs"
    fi
    fi

    #--with-guile=/usr/local --with-expat --with-lzma
    if [ $name == "gdb" ]; then
        configureArgs="--with-python=no $configureArgs"
    fi

    if [[ $platform == "macos" ]]; then
    if [[ $name == "gcc" || $name == "gdb" ]]; then
        configureArgs="--with-gmp=$(brew-path gmp) --with-mpfr=$(brew-path mpfr) --with-mpc=$(brew-path mpc) $configureArgs"
    fi
    fi

    if [ $platform == "windows" ]; then
        configureArgs="--host=i686-w64-mingw32.static $configureArgs"
    fi
    
    if [[ $name == "gcc" && $target == "x86_64-elf" ]]; then
        echoColor "        Installing config/i386/t-x86_64-elf"
        echo -e "MULTILIB_OPTIONS += mno-red-zone\nMULTILIB_DIRNAMES += no-red-zone" > ../gcc-$GCC_VERSION/gcc/config/i386/t-x86_64-elf
        echoColor "        Patching gcc/config.gcc"
        sed -i '/x86_64-\*-elf\*)/a \\ttmake_file="${tmake_file} i386/t-x86_64-elf"' ../gcc-$GCC_VERSION/gcc/config.gcc
    fi

    ../$name-$version/configure $configureArgs
    if [ $name == "gcc" ]; then
        make -j8 all-gcc MAKEINFO=true >> configure.log
    else
        make -j8 MAKEINFO=true  >> configure.log
    fi

    if [[ $name == "gcc" && $target == "x86_64-elf" ]]; then
        make -j8 all-target-libgcc CFLAGS_FOR_TARGET='$CFLAGS_FOR_TARGET -mcmodel=large -mno-red-zone' MAKEINFO=true >> make.log
    else
        make -j8 all-target-libgcc MAKEINFO=true >> make.log
    fi

    if [[ $name == "gcc" ]]; then
    sudo make -j8 install-gcc MAKEINFO=true >> install.log
    sudo make install-target-libgcc MAKEINFO=true >> install-libgcc.log
    else
    sudo make install MAKEINFO=true >> install.log
    fi
    
    if [[ $name == "gcc" && $target == "x86_64-elf" ]]; then
        if [ $platform == "windows" ]; then
            cd "${BUILD_TARGET}/no-red-zone/libgcc"
            sudo make install MAKEINFO=true >> windows-install-libgcc.log
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
