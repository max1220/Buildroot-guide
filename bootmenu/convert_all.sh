#!/bin/bash

LUA_PATH="./lua/?.lua;;" ./convert_to_pxbuf.lua --rgba font_tileset.png > data/font_tileset.pxba
LUA_PATH="./lua/?.lua;;" ./convert_to_pxbuf.lua --rgba gfx_tileset.png > data/gfx_tileset.pxba
