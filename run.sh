#!/bin/bash

# meson setup build --prefix=/usr --wipe
meson setup build --prefix=/usr
ninja -C build -v com.github.tudo75.xed-terminal-plugin-pot
ninja -C build -v com.github.tudo75.xed-terminal-plugin-update-po
ninja -C build -v com.github.tudo75.xed-terminal-plugin-gmo
ninja -v -C build
ninja -v -C build install
