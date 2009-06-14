#/bin/bash
ignore_directives="\.\(section\)\|\(file\)\|\(text\)\|\(type\)\|\(size\)\|\(ident\)\|\(globl\)"
export SFLAGS="-I../shared -ggdb3 -Wa,-g"

test -d bin || mkdir bin
rm -f bin/*
gcc -Os -fomit-frame-pointer -c -S -I ~/libsigsegv-2.6/include fourk.c
grep -v ${ignore_directives} fourk.s > temp.s && mv temp.s fourk.s
gcc -c -Os -fomit-frame-pointer ${FLAGS} main.S -L ~/libsigsegv-2.6/lib -o bin/fourk.o
ld -dynamic-linker /lib/ld-linux.so.2 /usr/lib/libc.so bin/fourk.o -o bin/fourk

