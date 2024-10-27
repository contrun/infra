#!/usr/bin/env bash
set -e
name=unamed
# placeholder will be replaced by actual username
placeholder=ttestt
# non-null value of multiplyInstances will start multiply curl process simultaneously
multiplyInstances=y
# shortest username length, default value 1
# max processes to run
maxProcs=10
# shortest username length, default value 20
lowerBound=1
# longest username length, default value 20
upperBound=20
# If this pattern matches output, the username is deemed unavailable
failurePattern=
# If this pattern matches output, the username is deemed available
successPattern=
# raw file to save all outputs
rawFile=usernames.raw
# file to save available usernames
successFile=usernames.available
# file to save unavailable usernames
failureFile=usernames.unavailable
# file to save usernames whose availbility is inconclusive
inconlusiveFile=usernames.inconclusive
# file to save command with exit code non-zero results
errorFile=usernames.error
# web request command to replace
cmd=()

while getopts ":n:p:P:m:l:u:s:f:S:F:E:" opt; do
        case $opt in
        n)
                name="$OPTARG"
                ;;
        p)
                placeholder="$OPTARG"
                ;;
        P)
                maxProcs="$OPTARG"
                ;;
        m)
                multiplyInstances="$OPTARG"
                ;;
        l)
                lowerBound="$OPTARG"
                ;;
        u)
                upperBound="$OPTARG"
                ;;
        s)
                successPattern="$OPTARG"
                ;;
        f)
                failurePattern="$OPTARG"
                ;;
        S)
                successFile="$OPTARG"
                ;;
        F)
                failureFile="$OPTARG"
                ;;
        E)
                errorFile="$OPTARG"
                ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
done

shift "$(($OPTIND - 1))"
cmd=("$@")
if [[ "0" -eq "${#cmd}" ]]; then
        echo "command not provided" >&2
        exit 1
fi

export cmd placeholder rawFile inconlusiveFile failureFile failurePattern successFile successPattern errorFile name
checkUserName() {
        username="$0"
        newcmd=("${@/$placeholder/$username}")
        result="$("${newcmd[@]}" 2>&1)"
        if [[ $? == 0 ]]; then
                if [[ -n "$failurePattern" ]] && grep -q -E "$failurePattern" <<<"$result"; then
                        tee -a "${failureFile}" <<<"$name username unavailable: $username"
                elif [[ -n "$successPattern" ]] && grep -q -E "$successPattern" <<<"$result"; then
                        tee -a "${successFile}" <<<"$name username available: $username"
                elif [[ -n "$successPattern" ]] || [[ -n "$failurePattern" ]]; then
                        tee -a "${inconlusiveFile}" <<<"$name username inconclusive: $username"
                fi
        else
                tee -a ${errorFile:-usererr} <<<"$name username error: $username"
        fi
        cat <<- EOF | tee -a "$rawFile"
$name username: $username
result:
$result
-------------------------
EOF
}

repl() { printf "$1"'%.s' $(seq 1 $2); }

export -f checkUserName

echoUsernames() {
        for i in $(seq "${lowerBound}" "${upperBound}"); do
                for letter in {a..z}; do
                        echo "$(repl "$letter" "$i")"
                done
        done
}

echoUsernames | xargs -I _REPLACE_ME_PLZ_ -t -r -P "$maxProcs" bash -c 'checkUserName "$@"' _REPLACE_ME_PLZ_ "${cmd[@]}"
