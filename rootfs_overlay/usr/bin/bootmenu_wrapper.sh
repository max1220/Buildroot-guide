#!/bin/sh
export LUA_PATH="/usr/bootmenu/?.lua;/usr/bootmenu/?/init.lua;/usr/bootmenu/lua/?.lua;/usr/bootmenu/lua/?/init.lua;;"
cd /usr/bootmenu/
luajit main.lua
