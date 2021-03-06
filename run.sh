#!/usr/bin/env bash
#
# This script runs SDElements as a containerized service. For more information
# please see the README.
#
# Copyright (c) 2018 SD Elements Inc.
#
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains
# the property of SD Elements Incorporated and its suppliers,
# if any.  The intellectual and technical concepts contained
# herein are proprietary to SD Elements Incorporated
# and its suppliers and may be covered by U.S., Canadian and other Patents,
# patents in process, and are protected by trade secret or copyright law.
# Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained
# from SD Elements Inc..

# Set strict mode
set -eu

# Version
# shellcheck disable=2034
version='0.0.2'

default_library_name='shtdlib.sh'
default_base_download_url='https://raw.githubusercontent.com/sdelements/shtdlib/master'
default_install_path='/usr/local/bin'

# Library download function, optionally accepts a full path/name and URL
function download_lib {
    local tmp_path="${1:-$(mktemp)}"
    local lib_url="${2:-${default_base_download_url}/${default_library_name}}"
    curl -s -l -o "${tmp_path}" "${lib_url}" || wget --no-verbose "${lib_url}" --output-document "${tmp_path}" || return 1
}

# Library install function, optionallly accepts a URL and a full path/name
# shellcheck disable=SC2120,SC2119
function install_lib {
    local lib_path="${1:-${default_install_path}/${default_library_name}}"
    local lib_name="${2:-$(basename "${lib_path}")}"
    local tmp_path="${3:-$(mktemp)}"

    echo "Installing library ${lib_name} to ${lib_path}"
    download_lib "${tmp_path}" "${default_base_download_url}/${lib_name}"
    mv "${tmp_path}" "${lib_path}" || sudo mv "${tmp_path}" "${lib_path}" || return 1
    chmod 755 "${lib_path}" || sudo chmod 755 "${lib_path}" || return 1
    # shellcheck disable=SC1091,SC1090
    source "${lib_path}"
    color_echo green "Installed ${lib_name} to ${lib_path} successfully"
}

# Library import function, accepts one optional parameter, name of the file to import
# shellcheck disable=SC2120,SC2119
function import_lib {
    local full_path
    local lib_name="${1:-${default_library_name}}"
    local lib_no_ext="${lib_name%.*}"
    local lib_basename_s="${lib_no_ext##*/}"
    full_path="$(readlink -f "${BASH_SOURCE[0]}" 2> /dev/null || realpath "${BASH_SOURCE[0]}" 2> /dev/null || greadlink -f "${BASH_SOURCE[0]}" 2> /dev/null)"
    full_path="${full_path:-${0}}"
    # Search current dir and walk down to see if we can find the library in a
    # parent directory or sub directories of parent directories named lib/bin
    while true; do
        local pref_pattern=( "${full_path}/${lib_name}" "${full_path}/${lib_basename_s}/${lib_name}" "${full_path}/lib/${lib_name}" "${full_path}/bin/${lib_name}" )
        for pref_lib in "${pref_pattern[@]}" ; do
            if [ -e "${pref_lib}" ] ; then
                echo "Importing ${pref_lib}"
                # shellcheck disable=SC1091,SC1090
                source "${pref_lib}"
                return 0
            fi
        done
        full_path="$(dirname "${full_path}")"
        if [ "${full_path}" == '/' ] ; then
            # If we haven't found the library try the PATH or install if needed
            # shellcheck disable=SC1091,SC1090
            source "${lib_name}" 2> /dev/null || install_lib "${default_install_path}/${lib_name}" "${lib_name}" && return 0
            # If nothing works then we fail
            echo "Unable to import ${lib_name}"
            return 1
        fi
    done
}

# Import the shell standard library
# shellcheck disable=SC2119
import_lib

# Record originnal directory
original_pwd="${PWD}"
project_path="$(readlink -f "${BASH_SOURCE[0]}" 2> /dev/null || realpath "${BASH_SOURCE[0]}" 2> /dev/null || greadlink -f "${BASH_SOURCE[0]}" 2> /dev/null)"
project_path="$(dirname "${full_path:-${0}}")"
cd "${project_path}" && add_on_exit "cd ${original_pwd}"

if [ "${#}" -eq 0 ] || [ "${1}" == '--help' ] ; then
    color_echo cyan 'Bash tester, tests a bash script/command on all currently supported bash versions'
    color_echo cyan "Typically this would be used as a git submodule and will map it's parent directory as /code"
    color_echo magenta "Usage: ${0} command_to_run"
    color_echo magenta  "Example: ${0} /code/run_app.sh --run_unit_tests"
    exit 1
fi

default_bash_images=( '3.0.22' \
                      '3.1.23' \
                      '3.2.57' \
                      '4.0.44' \
                      '4.1.17' \
                      '4.2.53' \
                      '4.3.48' \
                      '4.4.23' \
                      '5.0-beta' )

bash_images=( ${bash_images:-"${default_bash_images[@]}"} )

for version in "${bash_images[@]}" ; do
    echo "########## ${version} ##########"
    target_bash_version="${version}" docker-compose run bash-tester /usr/local/bin/bash -c "${@}"
    echo "############################"
done
