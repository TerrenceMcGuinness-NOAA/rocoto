#!/bin/bash
# Setup script for Rocoto environment
# Source this script to add Rocoto to your PATH

ROCOTO_ROOT="/home/tmcguinness/GITHUB/COPILOT/rocoto"

# Add Rocoto bin directory to PATH
export PATH="${ROCOTO_ROOT}/bin:${PATH}"

# Add library paths for the dependencies
export LD_LIBRARY_PATH="${ROCOTO_ROOT}/lib/libxml2/lib:${ROCOTO_ROOT}/lib/sqlite3/lib:${LD_LIBRARY_PATH}"

# Set Ruby library paths for the Ruby gems
export RUBYLIB="${ROCOTO_ROOT}/lib/libxml-ruby:${ROCOTO_ROOT}/lib/sqlite3-ruby:${ROCOTO_ROOT}/lib/thread:${RUBYLIB}"

echo "Rocoto environment setup complete!"
echo "Rocoto version: $(cat ${ROCOTO_ROOT}/VERSION)"
echo "Available commands:"
echo "  rocotostat, rocotorun, rocotocheck, rocotocomplete, rocotorewind, rocotoboot, rocotovacuum"
