#!/bin/sh
# Copyright (c) 2016 Technicolor

if [ -f /tmp/.X_000E50_RemoteAccess ]; then
  source /tmp/.X_000E50_RemoteAccess
  rm /tmp/.X_000E50_RemoteAccess
fi
