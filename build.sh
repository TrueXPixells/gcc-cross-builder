#!/usr/bin/env bash

set -e

BINUTILS_VERSION="2.42"
GCC_VERSION="13.2.0"
GDB_VERSION="14.2"

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --tar-path) TAR_PATH="$2";   shift; shift;;
    -t ) BUILD_TARGET="$2";      shift; shift;;
    -p ) BUILD_PLATFORM="$2";    shift; shift;;
    -bv) BINUTILS_VERSION="$2";  shift; shift;;
    -gv) GCC_VERSION="$2";       shift; shift;;
    -dv) GDB_VERSION="$2";       shift; shift;;
    *) shift ;;          
esac
done

mkdir work
cd work

mkdir out

AUTOCONF_ARGS="--target=$BUILD_TARGET --prefix=$(pwd)/out"

export PATH="$(pwd)/out/bin:$PATH"

# Binutils
curl -LO https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz
mkdir binutils-src binutils-build

cd binutils-src
tar -xvf ../binutils-$BINUTILS_VERSION.tar.xz
cd ..

cd binutils-build
../binutils-src/configure $AUTOCONF_ARGS --disable-nls --with-sysroot
make -j8
make install
cd ..

# GCC
curl -LO https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz
mkdir gcc-src gcc-build

cd gcc-src
tar -xvf ../gcc-$GCC_VERSION.tar.xz

if [ $BUILD_TARGET == "x86_64-elf" ]; then
    echo -e "MULTILIB_OPTIONS += mno-red-zone\nMULTILIB_DIRNAMES += no-red-zone" > ./gcc/config/i386/t-x86_64-elf
    sed -i '/x86_64-\*-elf\*)/a \\ttmake_file="${tmake_file} i386/t-x86_64-elf"' ./gcc/config.gcc
fi

cd ..

cd gcc-build

../gcc-src/configure $AUTOCONF_ARGS --disable-nls --enable-languages=c,c++ --without-headers

make -j8 all-gcc
if [ $BUILD_TARGET == "x86_64-elf" ]; then
    make -j8 all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=large -mno-red-zone'
else 
    make -j8 all-target-libgcc
fi
make install-gcc 
make install-target-libgcc
if [[ $BUILD_TARGET == "x86_64-elf" && $BUILD_PLATFORM == "windows" ]]; then
    # no-red-zone libgcc windows fix
fi
cd ..

# GDB
curl -LO https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.xz
mkdir gdb-src gdb-build

cd gdb-src
tar -xvf ../gdb-$GDB_VERSION.tar.xz
cd ..

cd gdb-build
# Mac fix
../gdb-src/configure $AUTOCONF_ARGS --disable-nls --with-sysroot --with-python=no
make -j8
make install
cd ..

# Tar them
cd out
tar -cJvf $TAR_PATH/out.tar.xz *