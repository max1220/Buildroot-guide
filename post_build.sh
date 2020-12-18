#!/bin/bash
# Goto project base directory(~/work/)
cd ${BASE_DIR}/../../

# Cross-compile all applications
./build_all.sh

# Install generated binaries to target
./install_all.sh
