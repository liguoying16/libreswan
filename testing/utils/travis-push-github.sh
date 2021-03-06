#!/bin/sh

# script to  push to github branches for travis tests.
# This not used to push tog github.com/libreswan/
#
# to push to https://travis-ci.org/antonyantony/libreswan/
#
# Copyright (C) 2017-2019 Antony Antony <antony@phenome.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.  See <https://www.gnu.org/licenses/gpl2.txt>.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.

set -eu

verbose=${verbose-''}

if [ "${verbose}" = "yes" ]; then
        set -x
fi

usage() {
        printf "usage $0:\n"
	printf "\t --dir <directory> : default ${DIR}\n"
}

function info() {
    if [[ -n "${verbose}" ]]; then
        echo "# $@"
    fi
}

BRANCHES="master travis-fedora-30 travis-fedora-29 travis-fedora-28 travis-fedora-rawhide travis-centos-8 travis-centos-7 travis-centos-6 travis-ubuntu-xenial travis-ubuntu-bionic travis-ubuntu-cosmic travis-ubuntu-disco travis-ubuntu-eoan travis-debian-experimental travis-debian-sid travis-debian-bullseye travis-debian-buster travis-debian-stretch travis-debian-jessie"

DIR="${DIR:-/home/build/git/libreswan}"
FETCH_REMOTE=yes

function list_default_branches() {
	printf "${BRANCHES}\n"
}

OPTIONS=$(getopt -o hvs: --long verbose,dir:,help,list-branches,no-fetch -- "$@")

if (( $? != 0 )); then
    err 4 "Error calling getopt"
fi

eval set -- "$OPTIONS"

while true; do
	case "$1" in
		-h | --help )
			usage
			exit 0
			;;
		--list-branches )
			list_default_branches
			exit 0
			;;
		--no-fetch | --no-etch-remote )
			FETCH_REMOTE=no
			shift
			;;
		--dir )
			DIR=$2
			shift 2
			;;
		-- ) shift; break ;;

		* )
			shift
			break
			;;
	esac
done

cd ${DIR} || exit;
TIME=$(date "+%Y%m%d-%H%M")
E_START=$(date "+%s")
LOG="Push the branches to github: "
COUNTER=0
HEAD_ID_START=$(git rev-parse --short HEAD)
HEAD_ID_END=''

LOG_FILE=${LOG_FILE:-/var/tmp/github-push-error.txt}
HIST_LOG_FILE=${HIST_LOG_FILE:-/var/tmp/github-push.txt}

log_success ()
{
	HEAD_ID_END=$(git rev-parse --short HEAD)
	E_END=$(date "+%s")
    	ELAPSED=$((E_END - E_START))
	LOG="${TIME} SUCCESS ${HEAD_ID_END} pushed ${COUNTER} branches elapsed ${ELAPSED} sec"
	if [ "${HEAD_ID_END}" != "${HEAD_ID_START}" ] ; then
       		printf "${LOG}\n" >> ${HIST_LOG_FILE}
		printf "${LOG}\n" >> ${LOG_FILE}
	fi
}

clean_up ()
{
	ARG=$?
	HEAD_ID_END=$(git rev-parse --short HEAD)
    	E_END=$(date "+%s")
    	ELAPSED=$((E_END - E_START))
    	LOG="${TIME} ERROR ${HEAD_ID_START} ${HEAD_ID_END} branches ${COUNTER} ${LOG} elapsed ${ELAPSED} sec"
}

count_br()
{
	for BR in ${BRANCHES}; do
		COUNTER=$((COUNTER + 1))
	done

}

git_work()
{
(
	git checkout master
	HEAD_ID_START=`git rev-parse --short HEAD`
	if [ "${FETCH_REMOTE}" = "yes" ]; then
		git fetch origin
	fi
	HEAD_ID_END=$(git rev-parse --short HEAD)
	if [ "${HEAD_ID_END}" = "${HEAD_ID_START}" ] ; then
		echo "${DATE} IGNORE ${HEAD_ID_START} NOTHING NEW"
		return 0
	fi
	git reset --hard origin/master
	echo "${TIME} start ${HEAD_ID_START} after ${HEAD_ID_END} ${COUNTER} branches"

	for BR in ${BRANCHES}; do
		LOG="${LOG} ${BR}"
		git checkout ${BR} || git checkout -b ${BR}
		git reset --hard master
		git push --follow-tags github -f
	done

	return 0
	echo ${LOG}
) > ${LOG_FILE} 2>&1
}

trap clean_up EXIT
count_br
git_work
log_success
