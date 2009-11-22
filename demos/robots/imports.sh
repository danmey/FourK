#!/bin/sh
grep lib gl.4k | grep '\"' |  awk '{ print $5 }' | sed 's/\(^.*\)\"/\1/g' | awk 'BEGIN { line = 2 } { print line " ccall: " $1 " "; line++ } '

