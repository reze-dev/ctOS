#!/usr/bin/env bash
mkdir -p /tmp/plymouth-test/themes
cp -r assets/ctos-plymouth /tmp/plymouth-test/themes/ctos
sed -i 's|/usr/share/plymouth/themes/ctos|/tmp/plymouth-test/themes/ctos|g' /tmp/plymouth-test/themes/ctos/ctos.plymouth

export PLYMOUTH_THEME_PATH=/tmp/plymouth-test/themes
export PLYMOUTH_DATADIR=/tmp/plymouth-test

plymouthd --debug --debug-file=/tmp/plymouth-debug.log --tty=/dev/tty
plymouth --show-splash
sleep 2
plymouth quit
cat /tmp/plymouth-debug.log | grep -i "error\|parse\|fail\|script"
