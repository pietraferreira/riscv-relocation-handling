#!/bin/bash

set -ue

TOPDIR="$(dirname $(cd $(dirname $0) && echo $PWD))"

source "${TOPDIR}/toolchain/EXPECTED_BRANCHES"

git clone -b "${BINUTILS_BRANCH}" \
    git@github.com:pietraferreira/corev-binutils-gdb.git \
    "${TOPDIR}/binutils"

git clone -b "${GDB_BRANCH}" \
    git@github.com:openhwgroup/corev-binutils-gdb.git \
    "${TOPDIR}/gdb"

#git clone -b "${GDB_SIM_BRANCH}" \
#    https://github.com/embecosm/riscv-binutils-gdb.git \
#    "${TOPDIR}/binutils-gdb-sim"

git clone -b "${GCC_BRANCH}" \
    git@github.com:openhwgroup/corev-gcc.git \
    "${TOPDIR}/gcc"

git clone -b "${NEWLIB_BRANCH}" \
    git@github.com:bminor/newlib.git \
    "${TOPDIR}/newlib"
