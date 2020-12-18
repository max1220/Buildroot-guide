#!/bin/bash
# This script gets called by the buildroot makefile.

# Goto project base directory
cd ${BASE_DIR}/../../

# Cross-compile all applications
./build_all.sh

# Install generated binaries to target
./install_all.sh
