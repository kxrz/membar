#!/bin/zsh
clear
"${0:A:h}/../MacOS/MemBar" mem 10
echo
exec "$SHELL" -l
