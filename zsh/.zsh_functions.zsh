#GLOBALS
LINUX_HOST1="10.24.12.84"
LINUX_HOST2="10.24.12.86"
CC_HOST="badaniya-vm"
BUILD_HOST="$CC_HOST"
FWDL_HOST="$LINUX_HOST2"
SS_PATH="$HOME/ss_team"
DOMAIN_NAME="extremenetworks.com"
BASE_SRC="$HOME/workspace/slxos"
MASTER_REPO_SRC="$HOME/workspace/badaniya/master"

CLEARTOOL=/usr/atria/bin/cleartool

NUM_CPU_CORES=`cat /proc/cpuinfo | grep processor | wc -l`

SWITCH_TERMINAL_GEOMETRY="89x25"
CHASSIS_TERMINAL_GEOMETRY="180x25"
FULL_TERMINAL_GEOMETRY="180x56"

if [[ -f $HOME/.private_zsh_functions ]]; then
    source $HOME/.private_zsh_functions.zsh
fi

host_ip()
{
    hostname -I | cut -d ' ' -f 1
}

# FUNCTIONS

function git_clone()
{
    local USAGE="git_clone <https://git_repository/path>"

    if [[ $# -lt 1 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local GIT_URL="$1"
    shift
    local GIT_TOKEN=`get_git_token`

    if [[ "$GIT_URL" =~ ^https://.* ]]; then
        # Do Nothing
        local DO=NOTHING
    else
        echo "$USAGE"
        return 1
    fi

    local GIT_USER=""
    read "GIT_USER?Git Username: "

    local USER=`urlencode $GIT_USER`

    local PASS=""
    if [[ -z "$GIT_TOKEN" ]]; then
        read -s "GIT_PASS?Git Password: "
        PASS=`urlencode $GIT_PASS`
    else
        PASS="$GIT_TOKEN"
    fi

    local NON_HTTPS_URL=${GIT_URL#https://}
    git clone "https://$GIT_USER:$PASS@$NON_HTTPS_URL" $@
}

function add_worktree()
{
    local USAGE="add_worktree <Repo Name - ex: GoDCApp | PlatformServices | PlatformCommonModels> <Private Branch Name - ex: EFA-12345> <Source Branch>"

    if [[ $# -lt 3 || $# -ge 4 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local REPO_NAME="$1"
    local GIT_BRANCH="$2"
    local GIT_SOURCE_BRANCH="$3"
    local RELATIVE_WORKTREE_PATH="../../$GIT_BRANCH/$REPO_NAME"

    pushd "$MASTER_REPO_SRC/$REPO_NAME" > /dev/null

    git pull && \
    git checkout "$GIT_SOURCE_BRANCH" && \
    git pull && \
    git worktree add -b "$USER/$REPO_NAME/$GIT_BRANCH" "$RELATIVE_WORKTREE_PATH" && \
    (git checkout master || git checkout main) && \
    cd "$RELATIVE_WORKTREE_PATH" && \
    git branch --set-upstream-to=origin/"$GIT_SOURCE_BRANCH"
    #go_work
}

function remove_worktree()
{
    local USAGE="remove_worktree <Repo Name - ex: GoDCApp | PlatformServices | PlatformCommonModels> <Private Branch Name - ex: EFA-12345>"

    if [[ $# -lt 2 || $# -ge 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local REPO_NAME="$1"
    local GIT_BRANCH="$2"
    local RELATIVE_WORKTREE_PATH="../$GIT_BRANCH/$REPO_NAME"
    local WORKTREE_PARENT_DIR=$(dirname "$MASTER_REPO_SRC/$RELATIVE_WORKTREE_PATH")

    pushd "$MASTER_REPO_SRC/$REPO_NAME" > /dev/null

    sudo git worktree remove --force "$MASTER_REPO_SRC/$RELATIVE_WORKTREE_PATH" && \
    git branch -D "$USER/$REPO_NAME/$GIT_BRANCH"

    popd > /dev/null 2>&1

    if [[ $(ls -1 $WORKTREE_PARENT_DIR | wc -l) -eq 0 ]]; then
        sudo rm -rf "$WORKTREE_PARENT_DIR"
    fi
}

function list_worktree()
{
    local USAGE="list_worktree <Repo Name - ex: GoDCApp | PlatformServices | PlatformCommonModels>"

    if [[ $# -lt 1 || $# -ge 2 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local REPO_NAME="$1"

    pushd "$MASTER_REPO_SRC/$REPO_NAME" > /dev/null

    git worktree list

    popd > /dev/null 2>&1
}

swagger_codegen()
{
    java -jar /usr/bin/swagger-codegen-cli.jar "$@"
}

get_postgresql_url() 
{
    local USAGE="get_postgresql_url <postgres user> <postgres pass> <postgres db name>"

    if [[ $# -lt 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local POSTGRES_USER="$1"
    local POSTGRES_PASS="$2"
    local POSTGRES_DBNAME="$3"
    local POSTGRES_IPPORT=`get_k3sdb_ipport`

    echo "postgresql://$POSTGRES_USER:$POSTGRES_PASS@$POSTGRES_IPPORT/$POSTGRES_DBNAME?sslmode=disable"
}

enable_nonroot_k3s() {
    sudo chmod 777 /etc/rancher/k3s/k3s.yaml
}

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
    local USAGE="rm_kube <service name>"

    if [[ $# -lt 1 || "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
    fi

    local SERVICE_NAME="$1"
    local KUBE_SERVICES=(`k3s kubectl -n efa get all | tac | awk '{print $1}' | grep $SERVICE_NAME`)

    echo "KUBE_SERVICES:" 

    for service in "${KUBE_SERVICES[@]}"; do
        echo "- $service"
        k3s kubectl -n efa delete $service
    done
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

    local PODNAME="$1"
    local INSHELL="$2"

    if [[ -z "$INSHELL" ]]; then
        INSHELL="ash"
    fi

    local CONTAINER=`ps_kube | grep $PODNAME | cut -d ' ' -f 1`

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

update_gopls()
{
    local USAGE="update_gopls [version]"

    local VERSION="$1"

    if [[ "$1" =~ (^-h$|^--help$) ]]; then
        echo "$USAGE"
        return 1
	fi

    if [[ -z "$VERSION" ]]; then
       VERSION="latest"
    fi

    ORIGINAL_GOPATH="$GOPATH"
    GOPATH="$GOBASEPATH"
    
    GO111MODULE=on go get golang.org/x/tools/gopls@"$VERSION"   

    GOPATH="$ORIGINAL_GOPATH"
}

function git-ls-lrt ()
{
    for k in `git branch | sed s/^..//`; do
        echo -e `git log -1 --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" "$k" 2>/dev/null`\\t"$k";
    done | sort -r | less -r
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

# Function: terminal_launcher
# Description: This will launch a preset multi-tabbed gnome terminal.  When chassis or switch is specified with a label then all terminal session output
#              Is logged to an appropriate labeled file under $HOME/sessionlogs.
function terminal_launcher()
{
    local USAGE="Usage: terminal_launcher < <dev|code|sim> <server host name to SSH into> | <chassis|switch> <Label for the device> >"

    if [[ $# -lt 3 || "$1" =~ (^-h$|^--help$) ]]; then
        echo $USAGE
        return 1
    fi


    local TERMINAL="mate-terminal"
    local TERM_CLASS=$2
    local PARAM=$3

    # Create a session log directory
    if [[ "$TERM_CLASS" == "switch" || "$TERM_CLASS" == "chassis" && -n "$PARAM" ]]; then
        if [ ! -d $HOME/sessionlogs ]; then
            mkdir $HOME/sessionlogs
        fi
    fi


    if [ "$TERM_CLASS" == "code" ]; then
        if [ -z "$PARAM" ]; then
            PARAM=$BUILD_HOST
        fi

        $TERMINAL --geometry=$FULL_TERMINAL_GEOMETRY \
            --tab --title=editor1 --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.0; done"\' --active \
            --tab --title=editor2 --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.1; done"\' \
            --tab --title=editor3 --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.2; done"\' \
            --tab --title=build   --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.3; done"\'
    elif [ "$TERM_CLASS" == "sim" ]; then 
        if [ -z "$PARAM" ]; then
            PARAM=$BUILD_HOST
        fi

        $TERMINAL --geometry=$FULL_TERMINAL_GEOMETRY \
            --tab --title=dcm1      --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.0; done"\' --active \
            --tab --title=dcm2      --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.1; done"\' \
            --tab --title=dcm3      --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.2; done"\' \
            --tab --title=dcmclient --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.3; done"\' \
            --tab --title=confdcli  --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.4; done"\' \
            --tab --title=misc_gdb  --command "bash -c 'while [ \"no\" == `xauth info | sed -n 's/File locked:[ ]*\([a-z]*\)/\1/p'` ]; do ssh -Yt $PARAM; sleep 0.6; done"\' 
    elif [ "$TERM_CLASS" == "dev" ]; then
        terminal_launcher $TERMINAL code $PARAM&
        sleep 2
        terminal_launcher $TERMINAL sim $PARAM

    elif [ "$TERM_CLASS" == "switch" ]; then
        if [ -z "$PARAM" ]; then
            $TERMINAL --geometry=$SWITCH_TERMINAL_GEOMETRY \
                --tab --active -t Console \
                --tab -t Telnet \
                --tab -t Telnet \
                --tab -t Telnet
        else
            $TERMINAL --geometry=$SWITCH_TERMINAL_GEOMETRY \
                --tab --active -t "$PARAM Console" -e "script -afq $HOME/sessionlogs/$PARAM.Console.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet1" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet1.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet2" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet2.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet3" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet3.`date +%Y%m%d.%H%M%S`.txt"
        fi
    elif [ "$TERM_CLASS" == "chassis" ]; then
        if [ -z "$PARAM" ]; then
            $TERMINAL --geometry=$CHASSIS_TERMINAL_GEOMETRY \
                --tab --active -t "MM1 Console" \
                --tab -t "MM2 Console" \
                --tab -t "LC# Console" \
                --tab -t "LC# Console" \
                --tab -t Telnet \
                --tab -t Telnet \
                --tab -t Telnet
        else
            $TERMINAL --geometry=$CHASSIS_TERMINAL_GEOMETRY \
                --tab --active -t "$PARAM MM1 Console" -e "script -afq $HOME/sessionlogs/$PARAM.MM1.Console.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM MM2 Console" -e "script -afq $HOME/sessionlogs/$PARAM.MM2.Console.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM LC# Console" -e "script -afq $HOME/sessionlogs/$PARAM.LC1.Console.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM LC# Console" -e "script -afq $HOME/sessionlogs/$PARAM.LC2.Console.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet1" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet1.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet2" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet2.`date +%Y%m%d.%H%M%S`.txt" \
                --tab -t "$PARAM Telnet3" -e "script -afq $HOME/sessionlogs/$PARAM.Telnet3.`date +%Y%m%d.%H%M%S`.txt"
        fi
    elif [ "$TERM_CLASS" == "full" ]; then
        $TERMINAL --geometry=$FULL_TERMINAL_GEOMETRY
    else
        $TERMINAL
    fi
}

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

        USERNAME="${USERPASS[1]}"
        PASSWORD="${USERPASS[2]}"
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

        USERNAME="${USERPASS[1]}"
        PASSWORD="${USERPASS[2]}"
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

function free_swap_mem()
{
    local FREE_MEM="$(free | grep 'Mem:' | awk '{print $7}')"
    local USED_SWAP="$(free | grep 'Swap:' | awk '{print $3}')"
    
    echo -e "Free memory:\t$FREE_MEM kB ($((FREE_MEM / 1024)) MiB)\nUsed swap:\t$USED_SWAP kB ($((USED_SWAP / 1024)) MiB)"
    if [[ $USED_SWAP -eq 0 ]]; then
        echo "Congratulations! No swap is in use."
    elif [[ $USED_SWAP -lt $FREE_MEM ]]; then
        echo "Freeing swap..."
        sudo swapoff -a
        sudo swapon -a
    else
        echo "Not enough free memory. Exiting."
        exit 1
    fi
}
