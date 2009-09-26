#!/bin/sh
m4 -s fourk2.S > t.S 
#gcc -gdb3 -ldl -DDEBUG t.S -o fourk-debug && 
#gcc -ldl -DREFERENCE t.S -o fourk-ref && 
#gcc -ldl t.S -o fourk2 &&
#&& cat bootstrap.4k | ./fourk-ref



# Amazing if we got here... Compile our shit
gcc -O1 -ffast-math -fomit-frame-pointer -c t.S -o t.o
#gcc tiny.S -nostdlib -Wl,--oformat,binary -o tiny
#gcc tiny2.S -nostdlib -o tiny2


#gcc striper.c -o striper
# Link it..
#/usr/lib/libSDL.so /usr/lib/libGL.so  /usr/lib/libglut.so
ld -dynamic-linker /lib/ld-linux.so.2 /usr/lib/libdl.so t.o  -o 4k-uncompressed




#ld -dynamic-linker /lib/ld-linux.so.2 /usr/lib/libc.so t.o -o fourk2
#./striper fourk2
#strip -s -R .comment -R .gnu.version 4k-uncompressed
#sstrip 4k-uncompressed

#cat bootstrap.4k | ./4k-uncompressed
#../image4k/image4k -link 4k-uncompressed image1.4ki

# Compress it
#cp unpack.header 4k 
#gzip -cn9 4k-uncompressed >> 4k 
#chmod +x 4k

#rm t.S t.o
