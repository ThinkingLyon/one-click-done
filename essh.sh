#!/bin/bash

log_error() {
  echo "$@" >&2
}

show_usage() {
  echo
  echo "Usage: ${0##*/} [-h] [-p port] [-i identity_file] <destination|_> <action> [<args>]"
  if [[ -n "$1" ]]; then
    exit $1
  fi
  echo "
These are actions supported:
    cmd <command> [args]
        Execute the command on the remote host.
    script <bash_script_file> [args]
        Execute the bash script on the remote host.
    upload <local_file> [remote_dir]
        Upload the file to the remote host.
    download <remote_file> [local_dir]
        Download the file from the remote host.

The destination may be specified as [user@]host. If no user specified, 'root' will be used.
If the destination is '_', the environment variable 'SSH_EXECUTE_DEFAULT_DESTINATION' will be used.

The arguments as follow can be specified by environment variables:
    destination: ESSH_DEFAULT_DESTINATION
    user: ESSH_DEFAULT_USER
    port: ESSH_DEFAULT_PORT
    identity_file: ESSH_DEFAULT_IDENTITY

Option '-h': Show this usage.
"
}

PORT="$ESSH_DEFAULT_PORT"
IDENTITY_FILE="$ESSH_DEFAULT_IDENTITY"
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

if [[ "$DESTINATION" == "_" ]]; then
  DESTINATION="$ESSH_DEFAULT_DESTINATION"
fi
if [[ -z "$DESTINATION" ]]; then
  log_error "No destination specified!"
  show_usage 1
fi

if [[ -z "$ACTION" ]]; then
  log_error "No action specified!"
  show_usage 1
fi

REMOTE_USER=$(cut -s -d"@" -f1 <<<"$DESTINATION")
if [[ -z "$REMOTE_USER" ]]; then
  REMOTE_USER="$ESSH_DEFAULT_USER"
fi
if [[ -z "$REMOTE_USER" ]]; then
  REMOTE_USER=root
fi

HOST=$(cut -d"@" -f2 <<<"$DESTINATION")

if [[ -n "$IDENTITY_FILE" ]]; then
  IDENTITY_PARAM="-i $IDENTITY_FILE"
fi

EXECUTE_HINT="$(date "+%Y-%m-%d %H:%M:%S") $REMOTE_USER@$HOST:"

get_port_param() {
  if [[ -n "$PORT" ]]; then
    echo "$1 $PORT"
  fi
}

exec_download() {
  local file=$1
  if [[ -z "$file" ]]; then
    log_error "No file specified!"
    return
  fi
  local local_dir=$2
  if [[ -z "$local_dir" ]]; then
    local_dir="."
  fi
  echo "$EXECUTE_HINT Download $file to $local_dir"
  scp $(get_port_param -P) $IDENTITY_PARAM $REMOTE_USER@$HOST:"$file" "$local_dir"
}

exec_upload() {
  local file=$1
  if [[ -z "$file" ]]; then
    log_error "No file specified!"
    return
  fi
  local remote_dir=$2
  local remote_dir_desc=$remote_dir
  if [[ -z "$remote_dir_desc" ]]; then
    remote_dir_desc="~"
  fi
  echo "$EXECUTE_HINT Upload $file to $remote_dir_desc"
  scp $(get_port_param -P) $IDENTITY_PARAM "$file" $REMOTE_USER@$HOST:"$remote_dir"
}

exec_script() {
  local file=$1
  if [[ -z "$file" ]]; then
    log_error "No script file specified!"
    return
  fi
  echo "$EXECUTE_HINT \$ bash $*"
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
