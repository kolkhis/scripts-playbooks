#!/usr/bin/rbash

# export PATH=/bin:/usr/bin
declare -i VERBOSE

declare REMOTE_USER
declare DEFAULT_USER='kolkhis'


# TODO(perf): Make destination(s) an array 
#   - Associative array?
#       [hostname]=192.168.4.11

declare DESTINATION=192.168.4.11
declare ENDPOINT

declare LOGFILE='/var/log/bastion.log'
declare PROMPT_STRING="
Welcome!
Select one of the following:

1. Connect to DestinationHost
2. Enter custom destination
3. Exit

> "

# TODO(perf): 
#   - Read from an SSH config for list of available connections
#       - Format?
#           - Host?
#           - Hostname?
#           - User@Hostname?
#       - Parse with perl, awk, grep
#   - Problem: This script does not have access to those parsing programs.  
#       - Solution:
#           - Parse in setup script and read from file for choices.

# parse-ssh-file() {
#     # TODO: Finish this -- dynamically generate choices based on SSH config file.
#     # Must happen in setup? No access to parsing tools (sed, awk, perl)
#     local CONFIG_FILE=
#     { [[ -f ~/.ssh/config ]] && CONFIG_FILE="$HOME/.ssh/config"; } || 
#         { [[ -f /etc/ssh/ssh_config ]] && CONFIG_FILE="/etc/ssh/ssh_config"; }
#     debug "Using config file: $CONFIG_FILE"
# }

# if [[ -f ~/.ssh/config ]] || [[ -f /etc/ssh/ssh_config ]]; then
#     parse-ssh-file
# fi


debug() {
    [[ $VERBOSE -gt 0 ]] && printf "[\x1b[33mDEBUG\x1b[0m]: %s\n" "$*"
}

err() {
    printf "[ \033[31mERROR\033[0m ]: " 
}

log-entry() {
    [[ $# -gt 0 ]] && printf "[%s]: %s\n" "$(date +%D-%T)" "$*" >> "$LOGFILE"
}

go-to-destination() {
    log-entry "User attempting to connect to ${REMOTE_USER:-$DEFAULT_USER}@$DESTINATION"
    if ! ping -c 1 "$DESTINATION"; then
        err; printf "Destination host is unresponsive!\n" && return 1
        log-entry "Server unreachable: $DESTINATION"
    fi

    ssh "${REMOTE_USER:-$DEFAULT_USER}@${DESTINATION}" || {
        err; printf "Failed to SSH to %s as %s!\n" "$DESTINATION" "${REMOTE_USER:-$DEFAULT_USER}"
        log-entry "SSH command failed for ${REMOTE_USER}@${DESTINATION}"
        return 1
    }
    return 0
}

get-user-input(){
    local INPUT
    read -r -n 2 -t 20 -p "$PROMPT_STRING" INPUT

    if [[ -n $INPUT ]]; then

        case $INPUT in
            1)
                printf "Going to DestinationHost.\n"
                go-to-destination || {
                    printf "Failed to connect!\n" && return 1
                }
                return 0
                ;;
            2)
                read -r -p "Enter SSH destination (user@ip): " ENDPOINT

                # POSIX-comliant:
                # REMOTE_USER="$(printf "%s" "$ENDPOINT" | cut -d '@' -f 1)"
                # DESTINATION="$(printf "%s" "$ENDPOINT" | cut -d '@' -f 2)"

                REMOTE_USER="${ENDPOINT%%@*}"
                DESTINATION="${ENDPOINT##*@}"

                # TODO(perf): Check if user was specified, along with @. If not, use
                # default user and handle @
                [[ $REMOTE_USER == "$DESTINATION" ]] &&
                    printf "No user given. Using %s.\n" "${REMOTE_USER:=$DEFAULT_USER}"

                debug "Going to '$DESTINATION' as '$REMOTE_USER'"
                log-entry "Custom location provided: ${REMOTE_USER}@${DESTINATION}"
                go-to-destination || {
                    printf "Failed to connect!\n"
                    log-entry "Call to go-to-destination failed with ${REMOTE_USER}@${DESTINATION}"
                    return 1
                }
                return 0
                ;;
            3)
                printf "Leaving now.\n"
                return 0
                ;;
            [^0-9])
                printf "You can only enter numbers.\n"
                debug "User entered invalid input: $INPUT"
                return 1
                ;;
            *)
                printf "Unknown input. Goodbye.\n"
                return 1
                ;;

        esac

    fi

}

while [[ -n $1 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=1
            shift;
            ;;
        *)
            printf "Unknown argument: %s\n" "$1"
            shift;
            ;;
    esac
done

# - If trying to connect to unresponsive host, kick back to input prompt
#   - Tried: 
#       - While loop w/ continue and 'CONNECTED' flag (locale error)
#       - For loop w/ attempts and connected flag (kicks back to jump box prompt after exiting destination)

get-user-input || {
    printf "Failed to connect!" # && continue
    log-entry "Failed connection to ${REMOTE_USER}@${DESTINATION}"
}

log-entry "Exiting bastion program."

exit 0

