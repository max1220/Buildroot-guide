#!/bin/sh
export LUA_PATH="/usr/bootmenu/lua/?.lua;/usr/bootmenu/lua/?/init.lua;;"
luajit /usr/bootmenu/main.lua
