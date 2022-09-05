#!/bin/bash -u
# Script for building a RISC-V GNU Toolchain from checked out sources
# (Universal version 1.2.0)

# Copyright (C) 2020-2022 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
SRCPREFIX=$(cd ../../ && pwd)
INSTALLPREFIX=${SRCPREFIX}/install
BUILDPREFIX=${SRCPREFIX}/build
LOGDIR="${SRCPREFIX}/logs/$(date +%Y%m%d-%H%M)"
TRIPLE=riscv32-corev-elf

# Options that allow overriding with command line options
PARALLEL_JOBS=$(nproc)
DEFAULTARCH=rv32i
DEFAULTABI=ilp32
MULTILIBGEN="rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d--"
BUGURL=
PKGVERS=
EXTRA_OPTS=
EXTRA_BINUTILS_OPTS=
EXTRA_GDB_OPTS=
EXTRA_GCC_OPTS=
EXTRA_NEWLIB_OPTS=

# Usage helper
usage() {
  echo "Usage for $0:"
  echo "  --bug-report-url=         Set bug reporting URL."
  echo "  --clean                   Erase build directory before building."
  echo "  --default-abi=            Set default ABI."
  echo "  --default-arch=           Set default architecture."
  echo "  --multilib-generator=     Set GCC's multilib generator option."
  echo "  --extra-binutils-opts=    Extra configure options for binutils."
  echo "  --extra-gcc-opts=         Extra configure options for gcc."
  echo "  --extra-gdb-opts=         Extra configure options for gdb."
  echo "  --extra-newlib-opts=      Extra configure options for newlib."
  echo "  --extra-opts=             Extra configure options for all stages."
  echo "  --release-version=        Set release number."
  echo "  --help                    Print this message."
  echo ""
  echo "The current default architecture/ABI is ${DEFAULTARCH}/${DEFAULTABI}."
  echo "The current multilib configuration is \"${MULTILIBGEN}\"."
  exit $1
}

# Parse command line options
for opt in "${@}"; do
  case ${opt} in
  "--clean")
    echo "Erasing ${BUILDPREFIX}..."
    rm -rf "${BUILDPREFIX}"
    ;;
  "--default-arch="*)
    DEFAULTARCH=${opt#--default-arch=}
    ;;
  "--default-abi="*)
    DEFAULTABI=${opt#--default-abi=}
    ;;
  "--multilib-generator="*)
    echo -- ${opt}
    MULTILIBGEN="${opt#--multilib-generator=}"
    ;;
  "--bug-report-url="*)
    BUGURL=${opt#--bug-report-url=}
    ;;
  "--release-version="*)
    PKGVERS=${opt#--release-version=}
    ;;
  "--extra-opts="*)
    EXTRA_OPTS="${EXTRA_OPTS} ${opt#--extra-opts=}"
    ;;
  "--extra-binutils-opts="*)
    EXTRA_BINUTILS_OPTS="${EXTRA_BINUTILS_OPTS} ${opt#--extra-binutils-opts=}"
    ;;
  "--extra-gdb-opts="*)
    EXTRA_GDB_OPTS="${EXTRA_GDB_OPTS} ${opt#--extra-gdb-opts=}"
    ;;
  "--extra-gcc-opts="*)
    EXTRA_GCC_OPTS="${EXTRA_GCC_OPTS} ${opt#--extra-gcc-opts=}"
    ;;
  "--extra-newlib-opts="*)
    EXTRA_NEWLIB_OPTS="${EXTRA_NEWLIB_OPTS} ${opt#--extra-newlib-opts=}"
    ;;
  "--help")
    usage 0
    ;;
  *)
    usage 1
    ;;
  esac
done

# If a BUGURL and PKGVERS has been provided, add these to EXTRA_OPTS
if [ "x${BUGURL}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-bugurl='${BUGURL}'"
fi
if [ "x${PKGVERS}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
fi

# Create log directory
mkdir -p ${LOGDIR}

# Determine whether to build binutils-gdb as one project or two, this depends
# on whether gdb/configure and binutils/configure exists. If both exist, then
# the separate build takes precedence.
if [ -e ${SRCPREFIX}/binutils/configure -a -e ${SRCPREFIX}/gdb/configure ]; then
  # Binutils
  LOGFILE="${LOGDIR}/binutils.log"
  echo "Building Binutils... logging to ${LOGFILE}"
  (
    set -e
    mkdir -p ${BUILDPREFIX}/binutils
    cd ${BUILDPREFIX}/binutils
    CFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    CXXFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    ../../binutils/configure            \
        --target=${TRIPLE}              \
        --prefix=${INSTALLPREFIX}       \
        --disable-werror                \
        --disable-gdb                   \
        ${EXTRA_OPTS}                   \
        ${EXTRA_BINUTILS_OPTS}
    make -j${PARALLEL_JOBS}
    make install
  ) > ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    echo "Error building Binutils, check log file!" > /dev/stderr
    exit 1
  fi

  # GDB
  LOGFILE="${LOGDIR}/gdb.log"
  echo "Building GDB... logging to ${LOGFILE}"
  (
    set -e
    mkdir -p ${BUILDPREFIX}/gdb
    cd ${BUILDPREFIX}/gdb
    CFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    CXXFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    ../../gdb/configure                 \
        --target=${TRIPLE}              \
        --prefix=${INSTALLPREFIX}       \
        --with-expat                    \
        --disable-werror                \
        ${EXTRA_OPTS}                   \
        ${EXTRA_GDB_OPTS}
    make -j${PARALLEL_JOBS} all-gdb
    make install-gdb
  ) > ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    echo "Error building GDB, check log file!" > /dev/stderr
    exit 1
  fi
else
  # Binutils-GDB
  LOGFILE="${LOGDIR}/binutils-gdb.log"
  echo "Building Binutils-GDB... logging to ${LOGFILE}"
  (
    set -e
    mkdir -p ${BUILDPREFIX}/binutils-gdb
    cd ${BUILDPREFIX}/binutils-gdb
    CFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    CXXFLAGS="-ggdb3 -O0 -Wno-error=implicit-function-declaration" \
    ../../binutils/configure            \
        --target=${TRIPLE}              \
        --prefix=${INSTALLPREFIX}       \
        --with-expat                    \
        --disable-werror                \
        ${EXTRA_OPTS}                   \
        ${EXTRA_BINUTILS_OPTS}          \
        ${EXTRA_GDB_OPTS}
    make -j${PARALLEL_JOBS}
    make install
  ) > ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    echo "Error building Binutils-GDB, check log file!" > /dev/stderr
    exit 1
  fi
fi

# GCC (Stage 1)
LOGFILE="${LOGDIR}/gcc-stage1.log"
echo "Building GCC (Stage 1)... logging to ${LOGFILE}"
(
  set -e
  cd ${SRCPREFIX}/gcc
  ./contrib/download_prerequisites
  mkdir -p ${BUILDPREFIX}/gcc-stage1
  cd ${BUILDPREFIX}/gcc-stage1
  ../../gcc/configure                                     \
      --target=${TRIPLE}                                  \
      --prefix=${INSTALLPREFIX}                           \
      --with-sysroot=${INSTALLPREFIX}/${TRIPLE}           \
      --with-newlib                                       \
      --with-system-zlib                                  \
      --without-headers                                   \
      --disable-shared                                    \
      --enable-languages=c                                \
      --disable-werror                                    \
      --disable-libatomic                                 \
      --disable-libmudflap                                \
      --disable-libssp                                    \
      --disable-quadmath                                  \
      --disable-libgomp                                   \
      --disable-nls                                       \
      --disable-bootstrap                                 \
      --enable-multilib                                   \
      --with-multilib-generator="${MULTILIBGEN}"          \
      --with-arch=${DEFAULTARCH}                          \
      --with-abi=${DEFAULTABI}                            \
      ${EXTRA_OPTS}                                       \
      ${EXTRA_GCC_OPTS}
  make -j${PARALLEL_JOBS}
  make install
) > ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  echo "Error building GCC, check log file!" > /dev/stderr
  exit 1
fi

# Newlib
LOGFILE="${LOGDIR}/newlib.log"
echo "Building Newlib... logging to ${LOGFILE}"
(
  set -e
  PATH=${INSTALLPREFIX}/bin:${PATH}
  mkdir -p ${BUILDPREFIX}/newlib
  cd ${BUILDPREFIX}/newlib
  CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 -Os" \
  ../../newlib/configure                             \
      --target=${TRIPLE}                             \
      --prefix=${INSTALLPREFIX}                      \
      --with-arch=${DEFAULTARCH}                     \
      --with-abi=${DEFAULTABI}                       \
      --enable-multilib                              \
      --enable-newlib-io-long-double                 \
      --enable-newlib-io-long-long                   \
      --enable-newlib-io-c99-formats                 \
      --enable-newlib-register-fini                  \
      ${EXTRA_OPTS}                                  \
      ${EXTRA_NEWLIB_OPTS}
  make -j${PARALLEL_JOBS}
  make install
) > ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  echo "Error building newlib, check log file!" > /dev/stderr
  exit 1
fi

# Nano-newlib
# NOTE: This configuration is taken from the config.log of a
# "riscv-gnu-toolchain" build
LOGFILE="${LOGDIR}/newlib-nano.log"
echo "Building newlib-nano... logging to ${LOGFILE}"
(
  set -e
  PATH=${INSTALLPREFIX}/bin:${PATH}
  mkdir -p ${BUILDPREFIX}/newlib-nano
  cd ${BUILDPREFIX}/newlib-nano
  CFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections" \
  ../../newlib/configure                             \
      --target=${TRIPLE}                             \
      --prefix=${BUILDPREFIX}/newlib-nano-inst       \
      --with-arch=${DEFAULTARCH}                     \
      --with-abi=${DEFAULTABI}                       \
      --enable-multilib                              \
      --enable-newlib-reent-small                    \
      --disable-newlib-fvwrite-in-streamio           \
      --disable-newlib-fseek-optimization            \
      --disable-newlib-wide-orient                   \
      --enable-newlib-nano-malloc                    \
      --disable-newlib-unbuf-stream-opt              \
      --enable-lite-exit                             \
      --enable-newlib-global-atexit                  \
      --enable-newlib-nano-formatted-io              \
      --disable-newlib-supplied-syscalls             \
      --disable-nls                                  \
      ${EXTRA_OPTS}
  make -j${PARALLEL_JOBS}
  make install

  # Manualy copy the nano variant to the expected location
  # Information obtained from "riscv-gnu-toolchain"
  for multilib in $(${INSTALLPREFIX}/bin/${TRIPLE}-gcc --print-multi-lib); do
    multilibdir=$(echo ${multilib} | sed 's/;.*//')
    for file in libc.a libm.a libg.a libgloss.a; do
      cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/lib/${multilibdir}/${file} \
         ${INSTALLPREFIX}/${TRIPLE}/lib/${multilibdir}/${file%.*}_nano.${file##*.}
    done
    cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/lib/${multilibdir}/crt0.o \
       ${INSTALLPREFIX}/${TRIPLE}/lib/${multilibdir}/crt0.o
  done
  mkdir -p ${INSTALLPREFIX}/${TRIPLE}/include/newlib-nano
  cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/include/newlib.h \
     ${INSTALLPREFIX}/${TRIPLE}/include/newlib-nano/newlib.h
) > ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  echo "Error building newlib-nano, check log file!" > /dev/stderr
  exit 1
fi

# GCC (stage 2)
LOGFILE="${LOGDIR}/gcc-stage2.log"
echo "Building GCC (Stage 2)... logging to ${LOGFILE}"
(
  set -e
  mkdir -p ${BUILDPREFIX}/gcc-stage2
  cd ${BUILDPREFIX}/gcc-stage2
  ../../gcc/configure                                     \
      --target=${TRIPLE}                                  \
      --prefix=${INSTALLPREFIX}                           \
      --with-sysroot=${INSTALLPREFIX}/${TRIPLE}           \
      --with-native-system-header-dir=/include            \
      --with-newlib                                       \
      --disable-shared                                    \
      --enable-languages=c,c++                            \
      --enable-tls                                        \
      --disable-werror                                    \
      --disable-libmudflap                                \
      --disable-libssp                                    \
      --disable-quadmath                                  \
      --disable-libgomp                                   \
      --disable-nls                                       \
      --enable-multilib                                   \
      --with-multilib-generator="${MULTILIBGEN}"          \
      --with-arch=${DEFAULTARCH}                          \
      --with-abi=${DEFAULTABI}                            \
      ${EXTRA_OPTS}                                       \
      ${EXTRA_GCC_OPTS}
  make -j${PARALLEL_JOBS}
  make install
) > ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  echo "Error building GCC, check log file!" > /dev/stderr
  exit 1
fi

echo "Build completed successfully."
