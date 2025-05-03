#!/bin/sh
#
# SPDX-License-Identifier: MIT
#
# Copyright 2024-2025 Joseph Kroesche
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

TEST_VER="0.3"

if [ -z "${BATS_HOME}" ]
then
    echo "BATS_HOME is not defined"
    exit 1
fi

# test directories layout
#
# test              - this directory, contains test scripts
# test/testrepo     - borg repo created for testing
# test/testfiles    - generated file tree to use for test backup
# test/testconfig   - custom location for config files
# test/borg_base_dir - BORG_BASE_DIR, borg cached and metadata for the test

TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
TEST_REPO="${TEST_DIR}/testrepo"
TEST_FILES="${TEST_DIR}/testfiles"
TEST_CONFIG="${TEST_DIR}/testconfig"

# unset some variables that might be in the environment
# the test needs to control the value of these
unset BORG_REPO
unset BS_LOG_PATH
unset BS_LOG_FILE
unset BS_SCRIPTS_CONFIG
unset XDG_CONFIG_HOME

# borg itself recognizes BORG_BASE_DIR for its own caches
export BORG_BASE_DIR="${TEST_DIR}/borg_base_dir"

# RAMDISK NOTES
#
# I have concern about repeatedly creating and deleting the file system and
# repo during testing. I dont know if this is a valid concern. One possibility
# is to create either or both in a ramdisk. On a Mac the following appears
# to be the way to create a ramdisk that is mounted at /Volumes/ramdisk.
# This example is 100M
#
# diskutil erasevolume HFS+ "ramdisk" `hdiutil attach -nomount ram://204800`
#
# I think that 'hdiutil detach /Volumes/ramdisk' is the correct way to free it.
#

# SETUP PER FILE
#
# For now, the test file system and the test repo are set up once for the file
# and all the test reuse it. Maybe it becomes necessary to do this per test.
# In that case consider ramdisk mentioned above.
#
setup_file() {
    # create the test file tree
    rm -rf "${TEST_FILES}"
    mkdir "${TEST_FILES}"
    cd "${TEST_FILES}"

    # create several folders, each containing several files, of random data
    echo "Creating test file tree"
    for d in {0..4}
    do
        mkdir "folder_${d}"
        cd "folder_${d}"
        for f in {0..8}
        do
            head -c 1024 < /dev/urandom > "file_${f}.bin"
        done
        cd ..
    done
    cd ..

    # initialize the test repo
    rm -rf "${TEST_REPO}"
    borg init --encryption none "${TEST_REPO}"
}

# TEARDOWN PER FILE
#
# This should reverse setup_file(). For now it is commented out in order to
# leave the artifacts while the test script is debugged.
#
#teardown_file() {
#    rm -rf "${TEST_FILES}"
#}

# SETUP/TEARDOWN PER TEST

setup() {
    # load helpers
    load "${BATS_HOME}/test_helper/bats-support/load"
    load "${BATS_HOME}/test_helper/bats-assert/load"
    load "${BATS_HOME}/test_helper/bats-file/load"

    # put scripts on the path for easy calling
    PATH="${TEST_DIR}/..:$PATH"

    # unalias in case they are aliased on the test system
    alias bs-backup=''
    unalias bs-backup
    alias bs-logs=''
    unalias bs-logs
    alias bs-agent=''
    unalias bs-agent
    alias bs-verify=''
    unalias bs-verify

    # make sure we are running from test dir
    cd "${TEST_DIR}"

    # the config directory has to exist before it can be used
    rm -rf "${TEST_CONFIG}"
    mkdir -p "${TEST_CONFIG}"

    # remove any existing config files to make sure we are starting clean
    rm -f "${TEST_DIR}/bs-repo.cfg"
    rm -f "${TEST_DIR}/bs-set-example.cfg"
    rm -f "${TEST_DIR}/bs-exclude-common.cfg"
    rm -f "${TEST_DIR}/bs-set-test.cfg"
    rm -f "${TEST_DIR}/../bs-repo.cfg"
    rm -f "${TEST_DIR}/../bs-set-example.cfg"
    rm -f "${TEST_DIR}/../bs-exclude-common.cfg"
    rm -f "${TEST_DIR}/../bs-set-test.cfg"
}

#teardown() {
#   # apparently teardown cant be empty
#    rm -f foobar
#}

@test "bs-backup basic version" {
    run bs-backup -V
    assert_success
    assert_line 'bs-backup from bs-scripts package 0.3'
}

######## BS-BACKUP ########

@test "bs-backup check no configs" {
    run bs-backup -g env
    assert_failure
    assert_output --partial "BS_SCRIPTS_CONFIG is not defined"
    run bs-backup -g xdg
    assert_failure
    assert_output --partial "XDG_CONFIG_HOME is not defined"
    assert_file_not_exists ./bs-repo.cfg
    assert_file_not_exists ../bs-repo.cfg
}

@test "bs-backup with missing config" {
    run bs-backup -b example
    assert_failure
    assert_output --partial "could not find configuration file"
}

@test "bs-backup attempting to use scripts dir" {
    run bs-backup -l -v
    assert_failure
    assert_line "Using scripts dir"
    assert_line "I could not find configuration file:"
}

@test "bs-backup generate config in cwd" {
    local CFGPATH="."
    run bs-backup -g cwd
    assert_success
    assert_file_exists "${CFGPATH}/bs-repo.cfg"
    assert_file_exists "${CFGPATH}/bs-exclude-common.cfg"
    assert_file_exists "${CFGPATH}/bs-set-example.cfg"

    # check bs-backup tries to use correct location for config
    run bs-backup -l -v
    assert_success
    assert_line "Using current directory for configuration"
}

@test "bs-backup generate config in scripts" {
    local CFGPATH=".."
    run bs-backup -g script
    assert_success
    assert_file_exists "${CFGPATH}/bs-repo.cfg"
    assert_file_exists "${CFGPATH}/bs-exclude-common.cfg"
    assert_file_exists "${CFGPATH}/bs-set-example.cfg"

    # check bs-backup tries to use correct location for config
    run bs-backup -l -v
    assert_success
    assert_line "Using scripts dir"
}

@test "bs-backup generate config in env" {
    local CFGPATH="${TEST_CONFIG}"
    export BS_SCRIPTS_CONFIG="${TEST_CONFIG}"
    run bs-backup -g env
    assert_success
    assert_file_exists "${CFGPATH}/bs-repo.cfg"
    assert_file_exists "${CFGPATH}/bs-exclude-common.cfg"
    assert_file_exists "${CFGPATH}/bs-set-example.cfg"

    # check bs-backup tries to use correct location for config
    run bs-backup -l -v
    assert_success
    assert_line "Using user defined BS_SCRIPTS_CONFIG as config location"
}

@test "bs-backup generate config in xdg" {
    local CFGPATH="${TEST_CONFIG}/bs-scripts"
    export XDG_CONFIG_HOME="${TEST_CONFIG}"
    run bs-backup -g xdg
    assert_success
    assert_file_exists "${CFGPATH}/bs-repo.cfg"
    assert_file_exists "${CFGPATH}/bs-exclude-common.cfg"
    assert_file_exists "${CFGPATH}/bs-set-example.cfg"

    # check bs-backup tries to use correct location for config
    run bs-backup -l -v
    assert_success
    assert_line "Using XDG_CONFIG_HOME for configuration"
}

@test "bs-backup list configs" {
    # generate some configs
    run bs-backup -g cwd
    assert_success

    # make a new backup set file
    cat << REPO_CFG > bs-set-test.cfg
BACKUP_SET_DESCRIPTION="Test custom backup set"
BACKUP_CUSTOM_FLAGS="--exclude 'foo/bar baz'"
BACKUP_SOURCE_PATHS="$(pwd)/testfiles"
REPO_CFG

    # list available test configs, verify config loc first
    run bs-backup -l -v
    assert_success
    assert_line "Using current directory for configuration"

    # avoind the verbosity and check the list
    run bs-backup -l
    assert_success

    expected='
Available backup configurations
-------------------------------
example          Example backup set
test             Test custom backup set'
    assert_output "${expected}"
}

@test "bs-backup run test backup" {
    # create the configs, use cwd
    run bs-backup -g cwd
    assert_success

    # update bs-repo.cfg to have usefule BORG_REPO
    echo "BORG_REPO=${TEST_REPO}" >> ./bs-repo.cfg

    # put something interesting in exclude-common
    cat << EXCLUDE_COMMON >> ./bs-exclude-common.cfg
*/.DS_*
EXCLUDE_COMMON

    # generate test set file
    cat << BS_SET > ./bs-set-test.cfg
BACKUP_SET_DESCRIPTION="Test backup set"
BACKUP_CUSTOM_FLAGS="--exclude 'foo/bar baz'"
BACKUP_SOURCE_PATHS="${TEST_FILES}"
BS_SET

    # run a backup
    run bs-backup -b test
    assert_success
    assert_line "terminating with success status, rc 0"
    assert_line --partial "Backup, Prune, and Compact finished successfully"
}

######## BS-LOGS ########

@test "bs-logs basic version" {
    run bs-logs -V
    assert_success
    assert_line 'bs-logs from bs-scripts package 0.3'
}

@test "bs-logs verify config env" {
    export BS_SCRIPTS_CONFIG="${TEST_CONFIG}"
    run bs-logs -v -l
    assert_failure # fails because config files is not actually there
    assert_line "Using user defined BS_SCRIPTS_CONFIG as config location"
}

@test "bs-logs verify config cwd" {
    # need to generate some configs in cwd so they can be found
    run bs-backup -g cwd
    assert_success
    run bs-logs -v -l
    assert_failure # generated config file does contain proper BS_LOG_PATH etc
    assert_line "Using current directory for configuration"
}

@test "bs-logs verify config xdg" {
    export XDG_CONFIG_HOME="${TEST_CONFIG}"
    # generate configs in xdg so they can be found
    run bs-backup -g xdg
    run bs-logs -v -l
    assert_failure # generated config file does contain proper BS_LOG_PATH etc
    assert_line "Using XDG_CONFIG_HOME for configuration"
}

@test "bs-logs verify config in .config" {
    skip "requires modifications to .config on host system"
}

@test "bs-logs verify config scripts" {
   # fallback with nothing else defined should be scripts dir
   run bs-logs -v -l
   assert_failure # config files not actually there
   assert_line "Using scripts dir"
}

@test "bs-logs list backup log" {
    # this first part just recreates a normal backup
    # but this time we need to save the log

    # create the configs, use cwd
    run bs-backup -g cwd
    assert_success

    # update bs-repo.cfg to have usefule BORG_REPO
    echo "BORG_REPO=${TEST_REPO}" >> ./bs-repo.cfg

    # need to add the BS_LOG_... vars to bs-repo
    echo "BS_LOG_PATH=$(pwd)" >> ./bs-repo.cfg
    echo "BS_LOG_FILE=bs-backup.log" >> ./bs-repo.cfg

    # put something interesting in exclude-common
    cat << EXCLUDE_COMMON >> ./bs-exclude-common.cfg
*/.DS_*
EXCLUDE_COMMON

    # generate test set file
    cat << BS_SET > ./bs-set-test.cfg
BACKUP_SET_DESCRIPTION="Test backup set"
BACKUP_CUSTOM_FLAGS="--exclude 'foo/bar baz'"
BACKUP_SOURCE_PATHS="${TEST_FILES}"
BS_SET

    # run a backup, save to log file
    bs-backup -b test >bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]

    # log file should now be generate and we can run some tests against it
    assert_file_exists "bs-backup.log"

    # do a log list and check for certain lines
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "1: "
    assert_line --partial " +++BACKUP: test"

}

@test "bs-logs extract added files" {
    # Generate a backup and log file
    run bs-backup -g cwd
    assert_success
    echo "BORG_REPO=${TEST_REPO}" >> ./bs-repo.cfg
    echo "BS_LOG_PATH=$(pwd)" >> ./bs-repo.cfg
    echo "BS_LOG_FILE=bs-backup.log" >> ./bs-repo.cfg
    bs-backup -b test >bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]
    assert_file_exists "bs-backup.log"

    # Extract added files
    run bs-logs -x 1 -a
    assert_success
    assert_output --partial "A /path/to/added/file"
}

@test "bs-logs extract modified files" {
    run bs-logs -x 1 -m
    assert_success
    assert_output --partial "M /path/to/modified/file"
}

@test "bs-logs extract error files" {
    run bs-logs -x 1 -e
    assert_success
    assert_output --partial "E /path/to/error/file"
}

@test "bs-logs prune log" {
    # Prune the log to keep only 1 backup
    run bs-logs -p 1
    assert_success
    run bs-logs -l
    assert_success
    assert_line --partial "1: +++BACKUP: test"
}

@test "bs-logs delete backup set" {
    # Delete the first backup set
    run bs-logs -d 1
    assert_success
    run bs-logs -l
    assert_success
    assert_no_line "1: +++BACKUP: test"
}

@test "bs-logs save log" {
    # Verify that a backup of the log is created
    run bs-logs -p 1
    assert_success
    assert_file_exists "bs-backup.log.0"
}

@test "bs-logs invalid option" {
    # Test invalid option handling
    run bs-logs -z
    assert_failure
    assert_output --partial "Invalid option"
}
