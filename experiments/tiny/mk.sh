gcc -c -nostdlib  tiny.s -o tiny.o
ld --oformat binary -e _start -Ttext 08048000 tiny.o -o tiny

