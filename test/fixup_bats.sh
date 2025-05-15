#!/usr/bin/env bash

# Source this into your shell to define variables for BATS
#
#     . ./fixup_bats.sh
#
# The BATS documentation suggests adding the BATS source as submodules to your
# project. Instead, I cloned the BATS repo elsewhere and this file sets up some
# variable to point to it.

export BATS_HOME="/Users/joe/Documents/Projects/tronics/bats"
alias bats="${BATS_HOME}/bats-core/bin/bats"
