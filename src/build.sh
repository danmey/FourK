#!/bin/sh
m4 -s fourk2.S > t.S 
gcc -gdb3 -DDEBUG t.S -o fourk-debug
# Amazing if we got here... Compile our shit
gcc -O1 -ffast-math -fomit-frame-pointer -c t.S -o t.o
#gcc striper.c -o striper
# Link it..
#    ld -dynamic-linker /lib/ld-linux.so.2 4k-uncompressed.o /usr/lib/libSDL.so /usr/lib/libGL.so  /usr/lib/libglut.so -o 4k-uncompressed
ld -dynamic-linker /lib/ld-linux.so.2 /usr/lib/libc.so t.o -o fourk2
#./striper fourk2
#strip -s -R .comment -R .gnu.version fourk2
#sstrip fourk2
# Compress it
#cp unpack.header 4k 
#gzip -cn9 fourk2 >> 4k 
#chmod +x 4k

#rm t.S t.o
