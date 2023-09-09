#!/bin/bash

set -x

find / -perm /4000 2>/dev/null
find / -perm /2000 2>/dev/null
find / -type f -perm -2 ! -type l -ls 2>/dev/nul
find / -nouser -o -nogroup 2>/dev/null