gcc -c -nostdlib  tiny.S -o tiny.o
ld --oformat binary -Ttext 08048000 tiny.o -o tiny

