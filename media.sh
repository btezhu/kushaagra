#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/utils.sh"

set -x

find / -name "*.xlsx" 2>/dev/null
find / -name "*.doc" 2>/dev/null
find / -name "*.docx" 2>/dev/null
find / -name "*.exe" 2>/dev/null
find / -name "*.mp3" 2>/dev/null
find / -name "*.mov" 2>/dev/null
find / -name "*.mp4" 2>/dev/null
find / -name "*.avi" 2>/dev/null
find / -name "*.mpg" 2>/dev/null
find / -name "*.mpeg" 2>/dev/null
find / -name "*.flac" 2>/dev/null
find / -name "*.m4a" 2>/dev/null
find / -name "*.flv" 2>/dev/null
find / -name "*.ogg" 2>/dev/null
find / -name "*.gif" 2>/dev/null
find / -name "*.png" 2>/dev/null
find / -name "*.jpg" 2>/dev/null
find / -name "*.jpeg" 2>/dev/null
find / -name "*.txt" 2>/dev/null
find / -name "*.tiff" 2>/dev/null
find / -name "*.bmp" 2>/dev/null
find / -name "*.aac" 2>/dev/null
find / -name "*.wav" 2>/dev/null
find / -name "*.wma" 2>/dev/null
find / -name "*.svg" 2>/dev/null
find / -name "*.pdf" 2>/dev/null
find / -name "*.zip" 2>/dev/null
find / -name "*.iso" 2>/dev/null
find / -name "*.rar" 2>/dev/null
find / -name "*.jar" 2>/dev/null
find / -name "*.msi" 2>/dev/null