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
COMMONS_DAEMON_VERSION="1.0.15"
COMMONS_DAEMON_URL="$MAVEN_URL/commons-daemon"
COMMONS_DAEMON_DOWNLOAD_URL="$COMMONS_DAEMON_URL/commons-daemon"
COMMONS_DAEMON_ARCHIVE_URL="$COMMONS_DAEMON_DOWNLOAD_URL/$COMMONS_DAEMON_VERSION"
COMMONS_DAEMON_ARCHIVE_NAME="commons-daemon-$COMMONS_DAEMON_VERSION-bin-windows.zip"

GOOGLECODE_URL="http://red5.googlecode.com"
FLASH_DEMO_URL="$GOOGLECODE_URL/svn/flash/trunk/deploy/"

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
    "svn"
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
    local release_version="$1-RELEASE"
    local release_tag="v$release_version"
    local dir="red5-server"

    if [ ! -d $dir ]; then
        log "** getting red5-server repository ..."
        run_command "git clone $SERVER_URL"
    fi

    cd $dir
    if [ "$version" = "trunk" ]; then
      log "** getting trunk version ..."
      run_command "git pull"
      SERVER_VERSION=$(mvn $MAVEN_HELP_PLUGIN -Dexpression=project.version | $GREP_VERSION)
      log "** target version: $SERVER_VERSION"
    else
      SERVER_VERSION=$release_version
      log "** target version: $release_tag"
      run_command "git checkout -b $release_tag $release_tag"
    fi

    run_command "rm -rf target"
    run_command "mvn dependency:copy-dependencies"
    run_command "mvn -Dmaven.test.skip=true -Dmaven.buildNumber.doUpdate=false package"

    [ ! -d "target" ] && return $RET_ERROR

    extract_red5_archive $SERVER_VERSION
    cd ..
}

extract_red5_archive() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    local archive_name="red5-server-${version}-server.tar.gz"
    local target_dir="target"
    local installable_dir="$target_dir/installable"
    local extract_dir="$installable_dir/red5-server-${version}"
    local demos_dir="$installable_dir/webapps/root/demos"
    local flash_demo_dir="flash_demo"

    log "** target dir: $target_dir"
    run_command "mkdir ./$installable_dir"
    run_command "tar zxvf $target_dir/$archive_name -C $installable_dir"
    run_command "mv $extract_dir/* $installable_dir"
    run_command "rmdir $extract_dir"

    if [ ! -d $flash_demo_dir ]; then
        log "** getting flash demo repository ..."
        run_command "svn checkout $FLASH_DEMO_URL ./$flash_demo_dir"
    fi

    run_command "rm -rf ./$flash_demo_dir/.svn"
    run_command "cp -r $flash_demo_dir $demos_dir"
}

make_setup_exe() {
    LAST_FUNCNAME=$FUNCNAME
    local _version="$1"
    local version="$(echo $_version | cut -d "-" -f1)"
    local snapshot="$(echo $_version | cut -d "-" -f2)"

    log "** making setup.exe ..."
    edit_red5_nsi $version
    run_command "rm -f setup-Red5-*.exe"
    run_command "makensis $RED5_NSI"
    if [ "$snapshot" = "SNAPSHOT" ]; then
        run_command "mv setup-Red5-*.exe setup-Red5-${_version}.exe"
    fi
}

edit_red5_nsi() {
    LAST_FUNCNAME=$FUNCNAME
    local version="$1"
    local build_root=".\/$WORK_DIR\/red5-server"
    local service_root=".\/$WORK_DIR\/red5-service"

    run_command "git checkout $RED5_NSI"
    sed -i "s/\!define VERSION .*/\!define VERSION $version/" $RED5_NSI
    sed -i "s/\!define BuildRoot .*/\!define BuildRoot $build_root/" $RED5_NSI
    sed -i "s/\!define ServiceRoot .*/\!define ServiceRoot $service_root/" $RED5_NSI
    run_command "git diff $RED5_NSI"
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
    echo "  - 1.0.3"
    echo "  - 1.0.2"
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
