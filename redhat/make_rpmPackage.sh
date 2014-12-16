#!/bin/bash --

# default configuration
DATE=$(date +"%Y-%m-%d %H:%M:%S")
PROG_NAME=$(basename $0)
LOG_FILE="$(pwd)/$(echo ${PROG_NAME} | sed "s/\.sh//").log"

# archive repositories for installing files
GITHUB_URL="https://github.com"

SERVER_VERSION=
SERVER_URL="$GITHUB_URL/Red5/red5-server"
SERVER_DOWNLOAD_URL="$SERVER_URL/releases/download/v\${version}-RELEASE/"
SERVER_ARCHIVE_NAME="red5-server-\${version}-RELEASE-server.tar.gz"

# requires
NEEDED_COMMANDS=(
    "curl"
    "make"
    "rpmbuild"
)

# for error check
RET_OK=0
RET_ERROR=1


#######################################################################
# Utilities
#######################################################################
log() {
    local date=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "$date - INFO : $*" | tee -a $LOG_FILE
}

error() {  # color red
    local date=$(date +"%Y-%m-%d %H:%M:%S")
    echo -en "\e[31m"
    echo -e "$date - ERROR: $*" | tee -a $LOG_FILE
    echo -en "\e[m"
}

run_command() {
    local eval cmd="$*"
    log "$ $cmd"
    eval "$*" | tee -a $LOG_FILE
}

download() {
    local url="$1"
    local archive_name="$2"
    run_command "curl -# -L $url -o $archive_name"
}

#######################################################################
# Functions
#######################################################################
get_red5_server_release() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    local download_url=$(eval echo $SERVER_DOWNLOAD_URL)
    local archive_name=$(eval echo $SERVER_ARCHIVE_NAME)
    local url="${download_url}/${archive_name}"

    if [ -f $archive_name ]; then
        log "** $archive_name is found so never download"
        return $RET_OK
    fi

    log "** getting red5-server archive ..."
    download $url $archive_name
    [ ! -f $archive_name ] && return $RET_ERROR

    return $RET_OK
}

make_rpm_package() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    log "** making rpm package ..."
    run_command "make clean"
    run_command "make VERSION=$version build"
    return $RET_OK
}

check_needed_commands() {
    LAST_FUNCNAME=$FUNCNAME
    local i=
    local cmd=
    local retval=$RET_OK

    log "* check commands this script uses"
    for ((i=0; i<${#NEEDED_COMMANDS[@]}; i++))
    do
        cmd=${NEEDED_COMMANDS[$i]}
        which $cmd > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            error "** '$cmd' command is not found, need to install!"
            retval=$RET_ERROR
        else
            run_command "$cmd --version"
        fi
    done
    return $retval
}

check_argument() {
    LAST_FUNCNAME=$FUNCNAME

    # not implemented now ...
    [ $# -eq 0 ] && return $RET_ERROR
    return $RET_OK
}

check_error() {
    local retval=$1
    [ $retval != $RET_OK ] && echo "Error in '$LAST_FUNCNAME' function"
    # not implemented now ...
    return $retval
}

usage() {
    echo "Usage: $0 [OPTION] red5_version"
    echo
    echo "red5_version is like this"
    echo "  - 1.0.x"
    echo "  - 1.0.3"
    echo "  - 1.0.2"
    echo
    echo "Options:"
    echo "  -h, --help"
    exit 0
}

main() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    [ -z "$version" ] && usage && return $RET_OK

    log "* Start $PROG_NAME on $DATE"

    # get red5-server release and build
    SERVER_VERSION=${version}
    log "** target version: $SERVER_VERSION"
    get_red5_server_release $SERVER_VERSION || return $?
    make_rpm_package $SERVER_VERSION || return $?

    log "* End   $PROG_NAME on $DATE"
    return $RET_OK
}


#######################################################################
# Run Main
#######################################################################
for OPT in "$@"
do
    case "$OPT" in
        '-h'|'--help'|-*)
            usage
            ;;
    esac
done

rm -f $LOG_FILE
check_needed_commands || exit $?
check_argument "$@" || usage $?
main "$@" || check_error $?
