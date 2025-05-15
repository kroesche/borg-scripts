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

# This script is for "unit testing" all the bs-scripts package.
# It uses the bash test framework BATS
# <https://bats-core.readthedocs.io/en/stable/index.html>
#
# To run it:
#
# * source the fixup script so env vars get defined:
#     . ./fixup_bats.sh
#     (see the comments in the fixup script)
#
# * run the test:
#     bats bs_test.bats
#
# a human readable output is generated

# This tests most of the functionality of the main scripts. It tests some
# error conditions but there is probably some missing.
# The tests are not completely independent, and it probably has to execute in
# the order it appears in the file. I did not want to create a new file
# system and archive for every test (in setup), so it reuses these at the file
# level. And later tests depend on something that happened earlier.
# Ideally everything would be set up from scratch in setup() and cleaned up
# in teardown() but thats not the way it works right now.

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
# test/testinstall  - custom test location for script installation
# test/testverify   - custom location for verify metadata
# test/borg_base_dir - BORG_BASE_DIR, borg cached and metadata for the test

TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
TEST_REPO="${TEST_DIR}/testrepo"
TEST_FILES="${TEST_DIR}/testfiles"
TEST_CONFIG="${TEST_DIR}/testconfig"
TEST_INSTALL="${TEST_DIR}/testinstall"
TEST_VERIFY="${TEST_DIR}/testverify"

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

# clean the test files tree
rm_testfiles() {
    rm -rf "${TEST_FILES}"
}

# create the tree of test files
mk_testfiles() {
    # create the test file tree
    rm_testfiles
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
}

# clean/remove the test repo
rm_repo() {
    # verify vars are real before rm -rf
    assert [ -n "${TEST_REPO}" ]
    assert [ -n "${BORG_BASE_DIR}" ]
    rm -rf "${TEST_REPO}"
    rm -rf "${BORG_BASE_DIR}"
}

# create/init the test repo
mk_repo() {
    # initialize the test repo
    rm -rf "${TEST_REPO}"
    borg init --encryption none "${TEST_REPO}"
}

# create a set of config files in the cwd (test dir)
#
mk_cwd_configs() {
    # create the configs, use cwd
    run bs-backup -g cwd
    assert_success

    # update bs-repo.cfg to have usefule BORG_REPO
    echo "BORG_REPO=${TEST_REPO}" >> ./bs-repo.cfg

    # need to add the BS_LOG_... vars to bs-repo
    echo "BS_LOG_PATH=$(pwd)" >> ./bs-repo.cfg
    echo "BS_LOG_FILE=bs-backup.log" >> ./bs-repo.cfg

    # add path for verify metadata
    echo "BS_VERIFY_CFG_PATH=${TEST_VERIFY}" >> ./bs-repo.cfg

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
}

# SETUP PER FILE
#
# For now, the test file system and the test repo are set up once for the file
# and all the test reuse it. Maybe it becomes necessary to do this per test.
# In that case consider ramdisk mentioned above.
#
setup_file() {
    # create the test file tree
    mk_testfiles

    # initialize the test repo
    mk_repo
}

# TEARDOWN PER FILE
#
# Remove artifacts that were created during the tests.
#
teardown_file() {
    #rm -rf "${TEST_FILES}"
    #rm -rf "${TEST_REPO}"
    rm -rf "${TEST_CONFIG}"
    #rm -rf "${TEST_VERIFY}"
    rm -rf "${BORG_BASE_DIR}"
}

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

    # same for install
    rm -rf "${TEST_INSTALL}"
    mkdir -p "${TEST_INSTALL}"

    # same for verify
    rm -rf "${TEST_VERIFY}"
    mkdir -p "${TEST_VERIFY}"

    # remove any existing config files to make sure we are starting clean
    rm -f "${TEST_DIR}/bs-repo.cfg"
    rm -f "${TEST_DIR}/bs-set-example.cfg"
    rm -f "${TEST_DIR}/bs-exclude-common.cfg"
    rm -f "${TEST_DIR}/bs-set-test.cfg"
    rm -f "${TEST_DIR}/bs-backup.log"
    rm -f "${TEST_DIR}/bs-backup.log.0"
    rm -f "${TEST_DIR}/../bs-repo.cfg"
    rm -f "${TEST_DIR}/../bs-set-example.cfg"
    rm -f "${TEST_DIR}/../bs-exclude-common.cfg"
    rm -f "${TEST_DIR}/../bs-set-test.cfg"
    rm -f "${TEST_DIR}/../bs-backup.log"
    rm -f "${TEST_DIR}/../bs-backup.log.0"
}

# runs after every test
teardown() {
    # this file is needed for one specific test and will mess up any other
    # tests if it is present
    rm -f "${TEST_FILES}/folder_3/unreadable.txt"
}

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
    # generate a set of config files
    mk_cwd_configs

    # list available test configs, verify config loc first
    run bs-backup -l -v
    assert_success
    assert_line "Using current directory for configuration"

    # avoid the verbosity and check the list
    run bs-backup -l
    assert_success

    expected='
Available backup configurations
-------------------------------
example          Example backup set
test             Test backup set'
    assert_output "${expected}"
}

@test "bs-backup run test backup" {
    # generate a set of config files
    mk_cwd_configs

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

    # create configs in cwd
    mk_cwd_configs

    # run a backup, save to log file
    bs-backup -b test > bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]

    # log file should now be generated and we can run some tests against it
    assert_file_exists "bs-backup.log"

    # do a log list and check for certain lines
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "1: "
    assert_line --partial " +++BACKUP: test"
    refute_line --partial "2: "

    # run a second backup and verify a second set appears in the log
    bs-backup -b test >> bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "2: "
    assert_line --partial " +++BACKUP: test"
}

# tests from here depend on prior test being run. It continues to use the
# existing repo that was generated in prior tests, and the tree of testfiles
# that was generated at the beginning of all the tests

@test "bs-logs extract added files" {
    # generate configs
    mk_cwd_configs

    # add a file to the test files tree so we can pick it up as "added"
    echo "file9" > "${TEST_FILES}/folder_0/file_9.bin"

    # now run a new backup
    bs-backup -b test > bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]
    assert_file_exists "bs-backup.log"

    # check log listing
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "1: "
    assert_line --partial " +++BACKUP: test"

    # Extract added files
    run bs-logs -x 1 -a
    assert_success
    assert_line "A ${TEST_FILES}/folder_0/file_9.bin"
}

@test "bs-logs extract modified files" {
    # generate configs
    mk_cwd_configs

    # overwrite one of the existing files in the testfiles so get a
    # "modified" file in the backup
    echo "foobar" >> "${TEST_FILES}/folder_2/file_2.bin"

    # now run a new backup
    bs-backup -b test > bs-backup.log 2>&1
    assert [ "$?" -eq 0 ]
    assert_file_exists "bs-backup.log"

    # check log listing
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "1: "
    assert_line --partial " +++BACKUP: test"

    # Extract modifed files
    run bs-logs -x 1 -m
    assert_success
    assert_line "M ${TEST_FILES}/folder_2/file_2.bin"
}

@test "bs-logs extract error files" {
    # generate configs
    mk_cwd_configs

    # create a new file in the test files backup set
    # disable read permissions. this should cause an error in the log
    echo "unreadable" >> "${TEST_FILES}/folder_3/unreadable.txt"
    chmod -r "${TEST_FILES}/folder_3/unreadable.txt"

    # now run a new backup
    # bs-backup returns error because bad file causes error/warning
    # backup still works though
    # if it returns a 1, then bats test script fails out
    # cant use run because it captures all the output that we want in the log
    bs-backup -b test > bs-backup.log 2>&1 || true
    assert_file_exists "bs-backup.log"

    # check log listing
    run bs-logs -l
    assert_success
    # TODO use regex for below
    assert_line --partial "1: "
    assert_line --partial " +++BACKUP: test"

    # Extract modifed files
    run bs-logs -x 1 -e
    assert_success
    assert_line "E ${TEST_FILES}/folder_3/unreadable.txt"
}

@test "bs-logs prune log" {
    # generate some config files
    mk_cwd_configs

    # run a backup 3 times to add multiple sets to the log
    # dont need to check return each time because bats will fail out
    # if bs-backup returns an error
    bs-backup -b test > bs-backup.log 2>&1
    bs-backup -b test >> bs-backup.log 2>&1
    bs-backup -b test >> bs-backup.log 2>&1

    # now check log listing. there should be 3 backup sets
    run bs-logs -l
    assert_success
    assert_line --partial "1: "
    assert_line --partial "2: "
    assert_line --partial "3: "

    # prune to 1 and verify
    run bs-logs -p 1
    assert_success
    # some stuff we expect to see from pruning operation
    assert_line "DELETE: 0"
    assert_line "DELETE: 1"
    assert_line --partial "Keeping"
    assert_line --partial "Deleting"

    run bs-logs -l
    assert_success
    assert_line --partial "1: "
    refute_line --partial "2: "
    refute_line --partial "3: "
}

@test "bs-logs delete backup set" {
    # the prune operation, tested above, already used the delete function
    # for this test, create two backups, and delete one, as a simple
    # check that delete option works

    # generate some config files
    mk_cwd_configs

    # run a backup 2 times to add multiple sets to the log
    # dont need to check return each time because bats will fail out
    # if bs-backup returns an error
    bs-backup -b test > bs-backup.log 2>&1
    bs-backup -b test >> bs-backup.log 2>&1

    # now check log listing. there should be 2 backup sets
    run bs-logs -l
    assert_success
    assert_line --partial "1: "
    assert_line --partial "2: "

    # delete set 2
    run bs-logs -d 2
    assert_success
    assert_line "DELETE: 2"

    # verify that its gone from the log
    run bs-logs -l
    assert_success
    assert_line --partial "1: "
    refute_line --partial "2: "
    refute_line --partial "3: "

    # verify a backup of the log file was made
    assert_file_exists "bs-backup.log.0"
}

@test "bs-logs invalid option" {
    # Test invalid option handling
    run bs-logs -z
    assert_failure
    assert_output --partial "Invalid option"
}

######## BS-INSTALL ########

@test "bs-install basic version" {
    run bs-install -V
    assert_success
    assert_line 'bs-install from bs-scripts package 0.3'
}

@test "bs-install install/remove scripts to test location" {
    assert_file_not_exists "${TEST_INSTALL}/bs-backup"

    # not test man page install because that goes to a system path
    run bs-install -s .. -d "${TEST_INSTALL}"
    assert_success
    assert_file_exists "${TEST_INSTALL}/bs-backup"
    assert_file_exists "${TEST_INSTALL}/bs-logs"
    assert_file_exists "${TEST_INSTALL}/bs-verify"
    assert_file_exists "${TEST_INSTALL}/bs-agent"

    # verify remove works
    run bs-install -r "${TEST_INSTALL}"
    assert_success
    assert_file_not_exists "${TEST_INSTALL}/bs-backup"
    assert_file_not_exists "${TEST_INSTALL}/bs-logs"
    assert_file_not_exists "${TEST_INSTALL}/bs-verify"
    assert_file_not_exists "${TEST_INSTALL}/bs-agent"
}

######## BS-VERIFY ########

@test "bs-verify basic version" {
    run bs-verify -V
    assert_success
    assert_line 'bs-verify from bs-scripts package 0.3'
}

@test "bs-verify verify config env" {
    export BS_SCRIPTS_CONFIG="${TEST_CONFIG}"
    run bs-verify -v -l
    assert_failure # fails because config files is not actually there
    assert_line "Using user defined BS_SCRIPTS_CONFIG as config location"
}

@test "bs-verify verify config cwd" {
    # need to generate some configs in cwd so they can be found
    run bs-backup -g cwd
    assert_success
    run bs-verify -v -l
    assert_failure # generated config file does contain proper BS_LOG_PATH etc
    assert_line "Using current directory for configuration"
}

@test "bs-verify verify config xdg" {
    export XDG_CONFIG_HOME="${TEST_CONFIG}"
    # generate configs in xdg so they can be found
    run bs-backup -g xdg
    run bs-verify -v -l
    assert_failure # generated config file does contain proper BS_LOG_PATH etc
    assert_line "Using XDG_CONFIG_HOME for configuration"
}

@test "bs-verify verify config in .config" {
    skip "requires modifications to .config on host system"
}

@test "bs-verify verify config scripts" {
   # fallback with nothing else defined should be scripts dir
   run bs-verify -v -l
   assert_failure # config files not actually there
   assert_line "Using scripts dir"
}

@test "bs-verify opt err -a" {
    mk_cwd_configs
    run bs-verify -a "foobar"
    assert_failure
    assert_output "Using -a by itself does nothing. You must also use -e"
}

@test "bs-verify opt err -e" {
    mk_cwd_configs
    run bs-verify -e "foobar"
    assert_failure
    assert_output "In order to extract (-e) you must specify an archive (-a)"
}

@test "bs-verify opt err -t" {
    mk_cwd_configs
    run bs-verify -t "foobar"
    assert_failure
    assert_line "In order to verify (-t) you need to either extract (-e/-a) or"
    assert_line "specify a test ID (-i) of a previously extracted backup"
}

@test "bs-verify opt err -i" {
    mk_cwd_configs
    run bs-verify -i 0
    assert_failure
    assert_output "Using -i alone does nothing. You also need -t"
}

@test "bs-verify extract then verify" {
    # generate configs
    mk_cwd_configs

    # get the most recent archive name from the repo
    borg list "${TEST_REPO}"> ./borg-list.txt
    ARCHIVE=$(tail -n 1 ./borg-list.txt|cut -f 1 -d ' ')
    
    # perform an extraction of the backup
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}"
    assert_success
    assert_line --partial "Extracting borg backup archive: ${ARCHIVE}"

    # list metadata
    run bs-verify -l
    assert_success
    # TODO use regex here
    assert_line --partial "0: "
    assert_line --partial "${ARCHIVE}"

    # look at metadata summary
    run bs-verify -s 0
    assert_success
    assert_line "Summary of test set: 0"
    assert_line "Archive:    ${ARCHIVE}"
    assert_line "Storage Usage of Extracted Files:"

    # now do verify against the recent extract
    run bs-verify -i 0 -t "/"
    assert_success
    assert_line --partial "Originals: "
    assert_line --partial "Extracted: "
    assert_line "All files verified"
}

@test "bs-verify extract and verify" {
    # generate configs
    mk_cwd_configs

    # get the most recent archive name from the repo
    borg list "${TEST_REPO}"> ./borg-list.txt
    ARCHIVE=$(tail -n 1 ./borg-list.txt|cut -f 1 -d ' ')

    # perform an extraction and verify of the backup
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}" -t "/"
    assert_success
    assert_line --partial "Originals: "
    assert_line --partial "Extracted: "
    assert_line "All files verified"
}

@test "bs-verify extract multiple and delete" {
    # generate configs
    mk_cwd_configs

    # get the most recent archive name from the repo
    borg list "${TEST_REPO}"> ./borg-list.txt
    ARCHIVE=$(tail -n 1 ./borg-list.txt|cut -f 1 -d ' ')
    
    # perform an extraction of the backup
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}"
    assert_success
    assert_line --partial "Extracting borg backup archive: ${ARCHIVE}"

    # do it a second time to generate a second extract metadata set
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}" -t "/"
    assert_success
    assert_line --partial "Extracting borg backup archive: ${ARCHIVE}"
    assert_line --partial "Originals: "
    assert_line --partial "Extracted: "
    assert_line "All files verified"

    # list metadata and verify 0 and 1 are present
    run bs-verify -l
    assert_success
    assert_line --partial "0: "
    assert_line --partial "1: "

    # delete item 0, verify 1 still present
    run bs-verify -c 0
    assert_success
    run bs-verify -l
    assert_success
    refute_line --partial "0: "
    assert_line --partial "1: "

    # delete remaining
    run bs-verify -c 1
    assert_success
    run bs-verify -l
    assert_success
    # output will be empty since all metadata was deleted
    assert_output ""

    # this test could/should be improved by also verifying that the cached
    # extracted data is deleted from the temp place it was stored
}

@test "bs-verify unbacked up file error" {
    # generate configs
    mk_cwd_configs

    # add a new file in the test file system, it has not been backed up
    echo "newfile" > "${TEST_FILES}/folder_0/newfile.txt"

    # get the most recent archive name from the repo
    borg list "${TEST_REPO}"> ./borg-list.txt
    ARCHIVE=$(tail -n 1 ./borg-list.txt|cut -f 1 -d ' ')

    # perform an extraction and verify of the backup
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}" -t "/" -n
    assert_failure
    assert_line --partial "Extracting borg backup archive: ${ARCHIVE}"
    assert_line --partial "Originals: "
    assert_line --partial "Extracted: "
    assert_line "The following files are missing or changed in the backup data:"
    assert_line --partial "/folder_0/newfile.txt"
}

@test "bs-verify changed file error" {
    # generate configs
    mk_cwd_configs

    # modify existing file in test files
    echo "changed" > "${TEST_FILES}/folder_4/file_4.bin"

    # get the most recent archive name from the repo
    borg list "${TEST_REPO}"> ./borg-list.txt
    ARCHIVE=$(tail -n 1 ./borg-list.txt|cut -f 1 -d ' ')

    # perform an extraction and verify of the backup
    run bs-verify -a "${ARCHIVE}" -e "${TEST_FILES}" -t "/" -n
    assert_failure
    assert_line --partial "Extracting borg backup archive: ${ARCHIVE}"
    assert_line --partial "Originals: "
    assert_line --partial "Extracted: "
    assert_line "The following files are missing or changed in the backup data:"
    assert_line --partial "/folder_4/file_4.bin"
}
