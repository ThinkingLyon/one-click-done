#!/bin/bash

log_error() {
  echo "$@" >&2
}

show_usage() {
  echo "Usage: ssh-execute [-h] [-p port] [-i identity_file] <destination> <action> [<args>]"
  if [[ -n "$1" ]]; then
    exit $1
  fi
  echo
  echo "Option '-h': Show this usage."
  echo
  echo "These are actions supported:"
  echo "    cmd <command> [args]"
  echo "        Execute the command on the remote host."
  echo "    script <bash_script_file> [args]"
  echo "        Execute the bash script on the remote host."
  echo "    upload <local_file> [remote_dir]"
  echo "        Upload the file to the remote host."
  echo "    download <remote_file> [local_dir]"
  echo "        Download the file from the remote host."
  echo
  echo "The destination may be specified as [user@]host. If no user specified, 'root' will be used."
  echo
  echo "The arguments as follow can be specified by global variables:"
  echo "    user: SSH_EXECUTE_DEFAULT_USER"
  echo "    port: SSH_EXECUTE_DEFAULT_PORT"
  echo "    identity_file: SSH_EXECUTE_DEFAULT_IDENTITY_FILE"
}

PORT="$SSH_EXECUTE_DEFAULT_PORT"
IDENTITY_FILE="$SSH_EXECUTE_DEFAULT_IDENTITY_FILE"
while (($#)); do
  case "$1" in
    -p)
      PORT=$2
      shift 2
      ;;
    -i)
      IDENTITY_FILE=$2
      shift 2
      ;;
    -h)
      show_usage
      exit
      ;;
    -* | --*=)
      log_error "Unknown flag: $1"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done
DESTINATION=$1
ACTION=$2
shift 2

if [[ -z "$DESTINATION" ]]; then
  log_error "The destination MUST be specified!"
  show_usage 1
fi

if [[ -z "$ACTION" ]]; then
  log_error "The action MUST be specified!"
  show_usage 1
fi

REMOTE_USER=$(cut -s -d"@" -f1 <<<"$DESTINATION")
if [[ -z "$REMOTE_USER" ]]; then
  REMOTE_USER="$SSH_EXECUTE_DEFAULT_USER"
fi
if [[ -z "$REMOTE_USER" ]]; then
  REMOTE_USER=root
fi

HOST=$(cut -d"@" -f2 <<<"$DESTINATION")

if [[ -n "$IDENTITY_FILE" ]]; then
  IDENTITY_PARAM="-i $IDENTITY_FILE"
fi

EXECUTE_HINT="$(date "+%Y-%m-%d %H:%M:%S") $REMOTE_USER@$HOST"

get_port_param() {
  if [[ -n "$PORT" ]]; then
    echo "$1 $PORT"
  fi
}

exec_download() {
  local remote_file=$1
  if [[ -z "$remote_file" ]]; then
    log_error "No file specified!"
    return
  fi
  local local_dir=$2
  if [[ -z "$local_dir" ]]; then
    local_dir="."
  fi
  echo Downloading...
  time scp $(get_port_param -P) $IDENTITY_PARAM $REMOTE_USER@$HOST:"$remote_file" "$local_dir"
}

exec_upload() {
  local file=$1
  if [[ -z "$file" ]]; then
    log_error "No file specified!"
    return
  fi
  local remote_dir=$2
  echo Uploading...
  time scp $(get_port_param -P) $IDENTITY_PARAM "$file" $REMOTE_USER@$HOST:"$remote_dir"
}

exec_script() {
  local file=$1
  if [[ -z "$file" ]]; then
    log_error "No script file specified!"
    return
  fi
  echo "$EXECUTE_HINT \$ $*"
  shift
  ssh $(get_port_param -p) $IDENTITY_PARAM $REMOTE_USER@$HOST "bash -s" "$@" <"$file"
}

exec_cmd() {
  if [[ -z "$*" ]]; then
    log_error "No command specified!"
    return
  fi
  echo "$EXECUTE_HINT \$ $*"
  ssh $(get_port_param -p) $IDENTITY_PARAM $REMOTE_USER@$HOST "$@"
}

case "$ACTION" in
  cmd)
    exec_cmd "$@"
    ;;
  script)
    exec_script "$@"
    ;;
  upload)
    exec_upload "$@"
    ;;
  download)
    exec_download "$@"
    ;;
  *)
    echo Unknown action: $ACTION
    ;;
esac
