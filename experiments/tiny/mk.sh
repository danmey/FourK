gcc -c -nostdlib  factor.s -o factor.o
ld --oformat binary -Ttext 08048000 factor.o -o factor

