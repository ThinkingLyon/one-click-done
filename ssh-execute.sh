#!/bin/bash

while (($#)); do
  case "$1" in
  -h)
    HOST=$2
    shift 2
    ;;
  -p)
    PORT=$2
    shift 2
    ;;
  -u)
    REMOTE_USER=$2
    shift 2
    ;;
  -i)
    IDENTITY_FILE=$2
    shift 2
    ;;
  cmd)
    ACTION=cmd
    shift
    break
    ;;
  script)
    ACTION=script
    shift
    break
    ;;
  upload)
    ACTION=upload
    shift
    break
    ;;
  download)
    ACTION=download
    shift
    break
    ;;
  -* | --*=)
    echo "Unknown flag: $1" >&2
    exit 1
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [ -z "$ACTION" ]; then
  echo "Usage:"
  echo "$0 <-h host> [-p port] [-u user] [-i identity_file] <action> [<args>]"
  echo
  echo "SUPPORTED ACTIONS:"
  echo "    cmd <command> [args]"
  echo "    script <bash_script_file> [args]"
  echo "    upload <local_file> [remote_dir]"
  echo "    download <remote_file> [local_dir]"
  exit
fi

if [ -z "$HOST" ]; then
  echo No host specified!
  exit
fi

if [ -z "$PORT" ]; then
  PORT=22
fi

if [ -z "$REMOTE_USER" ]; then
  REMOTE_USER=root
fi

if [ -n "$IDENTITY_FILE" ]; then
  IDENTITY_PARAM="-i $IDENTITY_FILE"
fi

exec_download() {
  local remote_file=$1
  if [ -z "$remote_file" ]; then
    echo No file specified!
    return
  fi
  local local_dir=$2
  if [ -z "$local_dir" ]; then
    local_dir="./"
  fi
  echo Downloading...
  time scp -P $PORT $IDENTITY_PARAM $REMOTE_USER@$HOST:"$remote_file" "$local_dir"
}

exec_upload() {
  local file=$1
  if [ -z "$file" ]; then
    echo No file specified!
    return
  fi
  local remote_dir=$2
  echo Uploading...
  time scp -P $PORT $IDENTITY_PARAM "$file" $REMOTE_USER@$HOST:"$remote_dir"
}

exec_script() { 
  local file=$1
  if [ -z "$file" ]; then
    echo No file specified!
    return
  fi
  shift
  ssh -p $PORT $IDENTITY_PARAM $REMOTE_USER@$HOST "bash -s" "$@" <"$file"
}

exec_cmd() {
  if [ -z "$*" ]; then
    echo "No command specified!"
    return
  fi
  ssh -p $PORT $IDENTITY_PARAM $REMOTE_USER@$HOST "$@"
}

date "+%Y-%m-%d %H:%M:%S"
echo Host: $HOST
echo Action: $ACTION
echo
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
  echo Unknown action: $ACTION!
  ;;
esac
