#!/bin/bash
DIR="$(dirname "$0")"
cd "$DIR"
nohup ./frpc -c ./frpc.toml >> ./frpc.log 2>&1 &
