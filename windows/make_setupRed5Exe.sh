#!/bin/bash --

# default configuration
DATE=$(date +"%Y-%m-%d %H:%M:%S")
WORK_DIR="work"
PROG_NAME=$(basename $0)
LOG_FILE="$(pwd)/$(echo ${PROG_NAME} | sed "s/\.sh//").log"

# archive repositories for installing files
GITHUB_URL="https://github.com"
SERVICE_URL="$GITHUB_URL/Red5/red5-service"

SERVER_VERSION=
SERVER_URL="$GITHUB_URL/Red5/red5-server"

MAVEN_URL="http://central.maven.org/maven2"
COMMONS_DAEMON_VERSION="1.0.14"
COMMONS_DAEMON_URL="$MAVEN_URL/commons-daemon"
COMMONS_DAEMON_DOWNLOAD_URL="$COMMONS_DAEMON_URL/commons-daemon"
COMMONS_DAEMON_ARCHIVE_URL="$COMMONS_DAEMON_DOWNLOAD_URL/$COMMONS_DAEMON_VERSION"
COMMONS_DAEMON_ARCHIVE_NAME="commons-daemon-$COMMONS_DAEMON_VERSION-bin-windows.zip"

# getting version for trunk
MAVEN_HELP_PLUGIN="org.apache.maven.plugins:maven-help-plugin:2.2:evaluate"
GREP_VERSION="eval egrep -v \"^\\[(INFO|WARNING)\\]\""

# NSIS settings
RED5_NSI="red5.nsi"

# requires
NEEDED_COMMANDS=(
    "curl"
    "egrep"
    "git"
    "makensis"
    "mvn"
    "tar"
    "unzip"
)

# command line options
OPT_CLEAN_BUILD="false"

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

re_create_dir() {
    local dir="$1"
    run_command "rm -rf ./$dir"
    run_command "mkdir ./$dir"
}

download() {
    local url="$1"
    local archive_name="$2"
    echo "Download $archive_name from $url"
    run_command "curl -# -L $url -o $archive_name"
}

#######################################################################
# Functions
#######################################################################
get_red5_service() {
    LAST_FUNCNAME=$FUNCNAME
    local dir="red5-service"

    if [ ! -d $dir ]; then
        log "** getting red5-service repository ..."
        run_command "git clone $SERVICE_URL ./$dir"
    fi

    cd $dir
    get_and_extract_commons_daemon_archive
    cd ..
}

get_and_extract_commons_daemon_archive() {
    LAST_FUNCNAME=$FUNCNAME
    local url="${COMMONS_DAEMON_ARCHIVE_URL}/$COMMONS_DAEMON_ARCHIVE_NAME"
    local dir=$(echo $COMMONS_DAEMON_ARCHIVE_NAME | sed "s/.zip//")

    log "** getting commons-daemon archive ..."
    re_create_dir $dir
    download $url $COMMONS_DAEMON_ARCHIVE_NAME
    run_command "(cd ./$dir && unzip ../$COMMONS_DAEMON_ARCHIVE_NAME)"
}

get_red5_server() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    echo "Get Red5 server ${version}"
    SERVER_VERSION=${version}
    # grab from releases
    # https://github.com/Red5/red5-server/releases/download/v1.0.8-M10/red5-server-1.0.8-M10.tar.gz
    local archive_name="red5-server-${version}.tar.gz"
    local url="https://github.com/Red5/red5-server/releases/download/v${version}/${archive_name}"
    log "** getting red5-server release..."
    download $url $archive_name

    run_command "tar zxvf $archive_name"

    # need to put the apidocs in red5-server/apidocs dir
    #echo "Work: ${WORK_DIR}"
    run_command "mkdir red5-server/apidocs"
    echo "Javadocs are online at http://red5.org/javadoc/" > red5-server/apidocs/javadocs.txt
}

make_setup_exe() {
    LAST_FUNCNAME=$FUNCNAME
    local _version="$1"
    echo "version: $1"
    local version="$(echo $_version | cut -d "-" -f1)"
    local snapshot="$(echo $_version | cut -d "-" -f2)"
    echo "VIProductVersion: $version snapshot: $snapshot"
    local setup_filename="setup-Red5-*.exe"

    log "** making setup.exe ..."
    run_command "rm -f ${WORK_DIR}/${setup_filename}"
    run_command "makensis -DVERSION=$version $RED5_NSI"

    [ ! -f $setup_filename ] && return $RET_ERROR

    if [ ! "$snapshot" = "RELEASE" ]; then
        run_command "mv $setup_filename setup-Red5-${_version}.exe"
    fi
    run_command "mv $setup_filename ${WORK_DIR}/"
    return $RET_OK
}

create_work_dir() {
    LAST_FUNCNAME=$FUNCNAME

    if [ "$OPT_CLEAN_BUILD" = "true" ]; then
        re_create_dir $WORK_DIR
    else
        run_command "mkdir -p $WORK_DIR"
    fi

    [ ! -d $WORK_DIR ] && return $RET_ERROR
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
    echo "  - trunk"
    echo "  - 1.0.8-M10"
    echo "  - 1.0.7-RELEASE"
    echo
    echo "Options:"
    echo "  -c, --cleanbuild: remove working directory before build"
    echo "  -h, --help"
    exit 0
}

main() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    [ -z "$version" ] && usage && return $RET_OK
    # "trunk" not supported until theres a good way to get the latest release number from github
    if [ "$version" = "trunk" ]; then
        version="1.0.8-M11"
    fi

    log "* Start $PROG_NAME on $DATE"

    create_work_dir || return $?
    cd $WORK_DIR
    log "** change dir to : $(pwd)"

    # get install files from red5-server and red5-service
    get_red5_service || return $?
    get_red5_server $version || return $?

    cd ..
    log "** change dir to : $(pwd)"

    # ${SERVER_VERSION} is set in get_red5_server() for trunk version
    make_setup_exe $SERVER_VERSION || return $?

    log "* End   $PROG_NAME on $DATE"
    return $RET_OK
}


#######################################################################
# Run Main
#######################################################################
for OPT in "$@"
do
    case "$OPT" in
        '-c'|'--cleanbuild')
            OPT_CLEAN_BUILD="true"
            shift
            ;;
        '-h'|'--help'|-*)
            usage
            ;;
    esac
done

rm -f $LOG_FILE
check_needed_commands || exit $?
check_argument "$@" || usage $?
main "$@" || check_error $?
