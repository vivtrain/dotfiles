#!/bin/bash

usage() { echo 'usage: pingwatch [-t TIMEOUT] DEST' >&2; exit 1; }

TIMEOUT=3
while getopts ":t:h" opt; do
  case $opt in
    t) TIMEOUT=$OPTARG ;;
    h) usage ;;
    :) echo "-$OPTARG requires an argument" >&2; usage ;;
    \?) echo "unknown option -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND  - 1))

TARGET=$1
[ -z "$TARGET" ] && usage

while true; do
  sleep 1
  if r=$(ping -c1 -W"$TIMEOUT" "$TARGET" 2>/dev/null | grep -oP 'time=\K[\d.]+'); then
    printf "\r\e[K%s  \e[32mUP\e[0m  %s ms" "$(date +%T)" "$r"
  else
    printf "\r\e[K%s  \e[31mDOWN\e[0m" "$(date +%T)"
  fi
done

