#GLOBALS
MASTER_REPO_SRC="$HOME/workspace/badaniya/master"
NUM_CPU_CORES=`cat /proc/cpuinfo | grep processor | wc -l`

if [[ -f $HOME/.private_zsh_functions.zsh ]]; then
    source $HOME/.private_zsh_functions.zsh
fi

# preexe - a built-in zsh function that is called before executing certain commands
preexec() 
{
    case $1 in
    goose*)
        # This sets up the goose config file with env variables before running any goose command
        envsubst < $HOME/.config/goose/config.yaml.in > $HOME/.config/goose/config.yaml
        ;;
    nvim*)
        # This sets up the git repo directory ENV when nvim is launched
        export GIT_DEV_REPO_PATH=$(git rev-parse --show-toplevel 2> /dev/null)
        ;;
    esac
}

host_ip()
{
    ip route get 1.1.1.1 | awk '{print $7}' | head -1
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
    (git checkout master || git checkout main || git checkout HEAD) && \
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

function git_ls_lrt ()
{
    for k in `git branch | sed s/^..//`; do
        echo -e `git log -1 --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" "$k" 2>/dev/null`\\t"$k";
    done | sort -r | less -r
}
function update_gopls()
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

function swagger_codegen()
{
    java -jar /usr/bin/swagger-codegen-cli.jar "$@"
}

function get_postgresql_url() 
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
