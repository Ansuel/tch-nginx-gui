#!/bin/sh
# Copyright (c) 2015 Technicolor

if [ -f /tmp/.remoteassistance ]; then
  remote=$(cat /tmp/.remoteassistance)
  if [ $remote == "1" ]; then
    /usr/bin/wget http://127.0.0.1:55555/ra?remote=on_permanent_random_ -O /dev/null
  else
    /usr/bin/wget http://127.0.0.1:55555/ra?remote=off_permanent_random_ -O /dev/null
  fi
fi
