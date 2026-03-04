# GLOBALS
NUM_CPU_CORES=`cat /proc/cpuinfo | grep processor | wc -l`

SWITCH_TERMINAL_GEOMETRY="89x25"
CHASSIS_TERMINAL_GEOMETRY="180x25"
FULL_TERMINAL_GEOMETRY="180x56"

if [[ -f $HOME/.private_bash_functions ]]; then
    source $HOME/.private_bash_functions
fi

host_ip()
{
    hostname -I | cut -d ' ' -f 1
}

get_pathenv()
{
    local SEARCH_PATH="$1"
    local PATH_ENV="$2"

    if [[ -n "$PATH_ENV" ]]; then
        for pathenv in `echo ${PATH_ENV//:/$'\n'}`; do
            if [[ $SEARCH_PATH =~ $pathenv ]]; then
                echo $pathenv
            fi
        done
    fi
}

function urlencode()
{
    # urlencode <string>

    local LANG=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;; 
        esac
    done
}

function find_gosrc_path()
{
    local INPUT_PATH="$1"
    local INPUT_PATH_ARRAY=(${INPUT_PATH//\// })
    local GOSRC=""

    if [[ " ${INPUT_PATH_ARRAY[@]} " =~ " src " ]]; then
        GOSRC=${INPUT_PATH%%/src*}
    fi

    echo $GOSRC
}

function set_gosrc_path()
{
    local GOSRC_PATH=`find_gosrc_path $PWD`
    local GOENV_PATH="$GOBASEPATH"

    if [[ "$GOSRC_PATH" =~ ^.*/GoDCApp/.*$ ]]; then
        GOSRC_PATH=`set_godcapp_gosrc_path $GOSRC_PATH`
    fi

    if [[ -n "$GOSRC_PATH" ]]; then
        if [[ -z "$GOENV_PATH" ]]; then
            GOENV_PATH="$GOSRC_PATH"
        fi

        export GOPATH="$GOENV_PATH"

        local GOBIN_PATH="${GOPATH//://bin:}"/bin

        if [[ ! "$PATH" =~ "$GOBIN_PATH" ]]; then
            export PATH="$GOBIN_PATH:$PATH"
        fi	

        set_ctag_cscope_path
    fi
}

# FUNCTIONS
ps_docker()
{
    local USAGE="ps_docker [container|image|names]"
    INPUT="$1"

    if [[ "$INPUT" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi
    
    if [[ -z "$INPUT" ]]; then
        INPUT="container"
    fi

    if [[ "$INPUT" == "container" ]]; then
        docker ps -a --format "{{.ID}}"
    elif [[ "$INPUT" == "image" ]]; then
        docker ps -a --format "table {{.ID}}\t{{.Image}}"
    elif [[ "$INPUT" == "names" ]]; then
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}"
    fi 
}

rm_docker()
{
    local USAGE="rm_docker <all | container id>"
    INPUT="$1"

    if [[ $# -lt 1 || $# -ge 2 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    if [[ "$INPUT" == "all" ]]; then 
        for container_id in `ps_docker`; do
            docker rm -vf $container_id
        done
    else
        docker rm -vf "$INPUT"
    fi
}

exec_docker()
{
    local USAGE="exec_docker <container id or name> [shell]"

    if [[ $# -lt 1 || $# -ge 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local CONTAINER="$1"   
    local INSHELL="$2"

    if [[ -z "$INSHELL" ]]; then
        INSHELL="ash"
    fi 

    echo docker exec -it "$CONTAINER" "$INSHELL"
    docker exec -it "$CONTAINER" "$INSHELL"
}

ps_kube()
{
    get_kube pods "$@"
}

get_kube()
{
    local USAGE="get_kube [options]"

    local OPTIONS="$1"

    if [[ "$OPTIONS" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi

    #echo k3s kubectl -n efa get "$@"
    k3s kubectl -n efa get "$@"
}

rm_kube()
{
    delete_kube pods "$@"
}

delete_kube()
{
    local USAGE="delete_kube [options]"

    local OPTIONS="$1"

    if [[ "$OPTIONS" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi

    #echo k3s kubectl -n efa delete "$@"
    k3s kubectl -n efa delete "$@"
}

create_kube()
{
    local USAGE="create_kube [options]"

    local OPTIONS="$1"

    if [[ "$OPTIONS" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi

    k3s kubectl -n efa create "$@"
}

apply_kube()
{
    local USAGE="apply_kube [options]"

    local OPTIONS="$1"

    if [[ "$OPTIONS" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi

    k3s kubectl -n efa apply "$@"
}

describe_kube()
{
    local USAGE="describe_kube [options]"

    local OPTIONS="$1"

    if [[ "$OPTIONS" == "help" ]]; then
        echo "$USAGE"
        return 1
    fi

    k3s kubectl -n efa describe "$@"
}

exec_kube()
{
    local USAGE="exec_kube <pod name> [shell]"

    if [[ $# -lt 1 || $# -ge 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local CONTAINER="$1"
    local INSHELL="$2"

    if [[ -z "$INSHELL" ]]; then
        INSHELL="ash"
    fi

    echo k3s kubectl -n efa exec "$CONTAINER" -it -- "$INSHELL"
    k3s kubectl -n efa exec "$CONTAINER" -it -- "$INSHELL"
}

log_kube()
{
    local USAGE="log_kube <pod name> [options]"

    if [[ $# -lt 1 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local CONTAINER="$1"
    shift
    local OPTIONS="$@"

    echo k3s kubectl -n efa logs "$CONTAINER" "$@"
    k3s kubectl -n efa logs "$CONTAINER" "$@"
}

set_term_title()
{
   echo -en "\033]0;$1\a"
}

function is_xauth_locked()
{
    local IS_XAUTH_LOCKED="yes"

    IS_XAUTH_LOCKED=`xauth info | grep "File locked" | awk '{print $3}'`

    echo $IS_XAUTH_LOCKED
}

function wait_for_xauth_lock()
{
    local IS_XAUTH_LOCKED=`is_xauth_locked`

    while [ "$IS_XAUTH_LOCKED" != "no" ]; do
        IS_XAUTH_LOCKED=`is_xauth_locked`
        sleep 0.2
    done
}

# Expect dependency
function expect_ssh()
{
    local USAGE="Usage: expect_ssh <hostname or ip> <username> <password> <ssh options> <ssh command>"

    if [[ $# -lt 5 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi

    local EXPECT_SSH_TIMEOUT="-1"
    local EXPECT_SSH_HOST="$1"
    local EXPECT_SSH_LOGIN="$2"
    local EXPECT_SSH_PASSWD="$3"
    local EXPECT_SSH_OPTIONS="$4"
    local EXPECT_SSH_CMD=$5

    if [[ -n "$EXPECT_SSH_CMD" ]]; then
        EXPECT_SSH_CMD=`printf %q "$EXPECT_SSH_CMD"`
    fi

    OUTPUT=$(expect -c "
    set timeout $EXPECT_SSH_TIMEOUT
    spawn ssh $EXPECT_SSH_OPTIONS $EXPECT_SSH_LOGIN@$EXPECT_SSH_HOST $EXPECT_SSH_CMD
    expect \"*assword:*\"
    send \"$EXPECT_SSH_PASSWD\r\"
    expect eof
    ")
    
    echo -e "\n
======= [expect_ssh started on ($EXPECT_SSH_HOST)] =======
[SSH COMMAND]:
ssh $EXPECT_SSH_OPTIONS $EXPECT_SSH_LOGIN@$EXPECT_SSH_HOST \"$EXPECT_SSH_CMD\"

[OUTPUT]:
$OUTPUT
======= [expect_ssh finished on ($EXPECT_SSH_HOST)] =======\n"
}

function multiple_expect_ssh()
{
    if [ $# -lt 2 ]; then
        echo "Usage: multiple_expect_ssh <\"non-interactive command\"> [username,password - example: 'root,fibranne' -  default: 'root'] <ip address(es)>"
        return 1
    fi

    local SSH_CMD="$1"
    shift

    # Check for username and password
    local USERNAME="root"
    local PASSWORD=""

    if [[ "$1" =~ [A-Za-z] ]]; then
        ORIGINAL_IFS=$IFS
        IFS=','
        local USERPASS=($1)
        IFS=$ORIGINAL_IFS

        USERNAME="${USERPASS[0]}"
        PASSWORD="${USERPASS[1]}"
        shift
    fi

    # Callisto switches hang when a public key is offered during ssh/scp operations
    local SSH_OPTIONS="-o PubKeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

    if [[ -z "$PASSWORD" ]]; then
        echo ""
        echo "Enter common password for $USERNAME: "
        read -s USER_PASSWD
    fi

    echo "[multiple_expect_ssh : Remotely executing on $@ ...]"

    # Turn off shell monitoring of backgrounded processes.
    set +m
    
    for i in "$@"; do
        { expect_ssh "$i" "$USERNAME" "$USER_PASSWD" "$SSH_OPTIONS" "$SSH_CMD" & } 2>/dev/null
    done

    wait

    # Turn on shell monitoring of backgrounded processes.
    set -m

    echo "[multiple_expect_ssh completed.]"
}

function expect_scp()
{
    local USAGE="Usage: expect_scp <scp command string - including source and destination> <scp options> <password>"

    if [[ $# -lt 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi

    local EXPECT_SCP_TIMEOUT="-1"
    local EXPECT_SCP_CMD="$1"
    local EXPECT_SCP_OPTIONS="$2"
    local EXPECT_SCP_PASSWD="$3"

    #if [[ -n "$EXPECT_SCP_CMD" ]]; then
    #    EXPECT_SCP_CMD=`printf %q "$EXPECT_SCP_CMD"`
    #fi

    OUTPUT=$(expect -c "
    set timeout $EXPECT_SCP_TIMEOUT
    spawn scp $EXPECT_SCP_OPTIONS $EXPECT_SCP_CMD
    expect \"*assword:*\"
    send \"$EXPECT_SCP_PASSWD\r\"
    expect eof
    ")
   
    echo -e "\n
======= [expect_scp started] =======
[SCP COMMAND]:
scp $EXPECT_SCP_OPTIONS \"$EXPECT_SCP_CMD\"

[OUTPUT]:
$OUTPUT
======= [expect_scp finished] =======\n"
}

function multiple_expect_scp()
{
    if [ $# -lt 3 ]; then
        echo "Usage: multiple_expect_scp <source - local file path> <destination - remote file path> <ip address(es)>"
        return 1
    fi

    local SCP_SOURCE_PATH="$1"
    shift
    local SCP_DESTINATION_PATH="$1"
    shift

    # Callisto switches hang when a public key is offered during ssh/scp operations
    local SCP_OPTIONS="-o PubKeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

    echo ""
    echo "Enter common root scp password: "
    read -s ROOT_PASSWD

    echo "[multiple_expect_scp : Remotely copying to $@ ...]"

    # Turn off shell monitoring of backgrounded processes.
    set +m

    for i in "$@"; do
        local SCP_CMD="$SCP_SOURCE_PATH root@$i:$SCP_DESTINATION_PATH"
        { expect_scp "$SCP_CMD" "$SCP_OPTIONS" "$ROOT_PASSWD" & } 2>/dev/null
    done

    wait

    # Turn on shell monitoring of backgrounded processes.
    set -m

    echo "[multiple_expect_scp completed.]"
}

function multiple_expect_remote_to_local_scp()
{
    if [ $# -lt 3 ]; then
        echo "Usage: multiple_expect_remote_to_local_scp <source - remote file path> <destination - local file path> <ip address(es)>"
        return 1
    fi

    local SCP_SOURCE_PATH="$1"
    shift
    local SCP_DESTINATION_PATH="$1"
    shift

    # Callisto switches hang when a public key is offered during ssh/scp operations
    local SCP_OPTIONS="-o PubKeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

    echo ""
    echo "Enter common root scp password: "
    read -s ROOT_PASSWD

    echo "[multiple_expect_remote_to_local_scp : Remotely copying from $@ ...]"

    # Turn off shell monitoring of backgrounded processes.
    set +m

    for i in "$@"; do
        if [[ ! -d "$SCP_DESTINATION_PATH/$i" ]]; then
            mkdir -p "$SCP_DESTINATION_PATH/$i"
        fi

        local SCP_CMD="root@$i:$SCP_SOURCE_PATH $SCP_DESTINATION_PATH/$i"
        { expect_scp "$SCP_CMD" "$SCP_OPTIONS" "$ROOT_PASSWD" & } 2>/dev/null
    done

    wait

    # Turn on shell monitoring of backgrounded processes.
    set -m

    echo "[multiple_expect_remote_to_local_scp completed.]"
}

function expect_telnet()
{
    local USAGE="Usage: expect_telnet <hostname or ip> <username> <password> <telnet command>"

    if [[ $# -lt 4 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi

    local EXPECT_TELNET_TIMEOUT="-1"
    local EXPECT_TELNET_HOST="$1"
    local EXPECT_TELNET_LOGIN="$2"
    local EXPECT_TELNET_PASSWD="$3"
    local EXPECT_TELNET_CMD="$4"
    local CTRL_C="\003"

    if [[ -n "$EXPECT_TELNET_CMD" ]]; then
        EXPECT_TELNET_CMD=`printf %q "$EXPECT_TELNET_CMD"`
    fi

    OUTPUT=$(expect -c "
    set timeout $EXPECT_TELNET_TIMEOUT 
    spawn telnet -l $EXPECT_TELNET_LOGIN $EXPECT_TELNET_HOST
    expect \"*assword:*\"
    send \"$EXPECT_TELNET_PASSWD\r\"
    expect {
        \"*Control-C*\"                 { send \"$CTRL_C\"; exp_continue }
        \"*$EXPECT_TELNET_LOGIN>*\"     { send \"$EXPECT_TELNET_CMD\r\" }
        \"*$EXPECT_TELNET_LOGIN*#*\"    { send \"$EXPECT_TELNET_CMD\r\" }
        eof
    }
    ") 

    echo -e "\n
======= [expect_telnet started on ($EXPECT_TELNET_HOST)] =======
[TELNET COMMAND]:
telnet -l $EXPECT_TELNET_LOGIN $EXPECT_TELNET_HOST \"$EXPECT_TELNET_CMD\"

[OUTPUT]:
$OUTPUT
======= [expect_telnet finished on ($EXPECT_TELNET_HOST)] =======\n"
}

function multiple_expect_telnet()
{
    if [ $# -lt 2 ]; then
        echo "Usage: multiple_expect_telnet <\"non-interactive command\"> <ip address(es)>"
        return 1
    fi

    local TELNET_CMD="$1"
    shift

    # Check for username and password
    local USERNAME="root"
    local PASSWORD=""

    if [[ "$1" =~ [A-Za-z] ]]; then
        ORIGINAL_IFS=$IFS
        IFS=','
        local USERPASS=($1)
        IFS=$ORIGINAL_IFS

        USERNAME="${USERPASS[0]}"
        PASSWORD="${USERPASS[1]}"
        shift
    fi

    if [[ -z "$PASSWORD" ]]; then
        echo ""
        echo "Enter common password for $USERNAME: "
        read -s USER_PASSWD
    fi

    echo "[multiple_expect_telnet : Remotely executing on $@ ...]"

    # Turn off shell monitoring of backgrounded processes.
    set +m

    for i in "$@"; do
        { expect_telnet "$i" "$USERNAME" "$USER_PASSWD" "$TELNET_CMD" & } 2>/dev/null
    done

    wait

    # Turn on shell monitoring of backgrounded processes.
    set -m

    echo "[multiple_expect_telnet completed.]"
}

function get_private_shared_memory()
{
    local USAGE="Usage: get_private_shared_memory <IP Address>"
    local HOST_IP="$1"
    local HOST_CMD='smaps -t `pidof Dcmd.Linux.powerpc` | grep Total | sed -n "s/.* \([0-9]*\) KB | Total$/\1/p"'
    local HOST_OPTIONS='-o PubKeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

    if [[ $# -lt 1 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi

    expect_ssh "$HOST_IP" "root" "fibranne" "$HOST_OPTIONS" "$HOST_CMD"
}

function get_process_file_descriptor_usage()
{
    local USAGE="Usage: get_process_file_descriptor_usage <Process Name> <IP Address>"
    local PROCESS_NAME="$1"
    local HOST_IP="$2"
    local HOST_CMD='ls -1 /proc/`pidof '$PROCESS_NAME'`/fd | wc -l'
    local HOST_OPTIONS='-o PubKeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

    if [[ $# -lt 2 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi

    expect_ssh "$HOST_IP" "root" "fibranne" "$HOST_OPTIONS" "$HOST_CMD"
}
