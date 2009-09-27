# Replace with something meaningful on mac OS X
LIB=/lib/ld-linux.so.2 /usr/lib/libSDL.so /usr/lib/libGL.so /usr/lib/libglut.so /usr/lib/libGLEW.so
CC=gcc -std=c99 -pedantic -c -Os -fomit-frame-pointer -I/usr/include/GL 
OUT=./bin
robots: bytecode.m4 intro.m4 stack.h alloc.h run.h stack.c alloc.c run.c matrix.c robots.c
	m4 intro.m4 > intro.c
	$(CC) stack.c -o $(OUT)/stack.o
	$(CC) alloc.c -o $(OUT)/alloc.o
	$(CC) run.c  -o $(OUT)/run.o
	$(CC) matrix.c -o $(OUT)/matrix.o
	$(CC) robots.c -o $(OUT)/robots.o
	ld -dynamic-linker /lib/ld-linux.so.2 $(OUT)/stack.o $(OUT)/alloc.o $(OUT)/run.o $(OUT)/matrix.o $(OUT)/robots.o /usr/lib/libSDL.so /usr/lib/libGL.so /usr/lib/libglut.so -o robots

robots2:
	gcc -std=c99 -pedantic -Os -fomit-frame-pointer -I/usr/include/GL -lGL -lglut -lSDL -o robots2 stack.c alloc.c run.c matrix.c robots.c
# -g -std=c99 -pedantic -lm -lSDL -lGL -lglut
# gcc -Os -fomit-frame-pointer -c [filename].c
# ld -dynamic-linker /lib/ld-linux.so.2 [filename].o /usr/lib/libSDL.so /usr/lib/libGL.so -o [filename]

intro4k:
	cp ./robots ./intro
	strip -s -R .comment -R .gnu.version intro 
	sstrip intro 
	cp unpack.header 4k 
	gzip -cn9 intro >> 4k 
	chmod +x 4k
	ls -l 4k


all: intro.o v3.o flower.o 
	ld -dynamic-linker $(LIB) intro.o v3.o flower.o -o intro

perlin: fake_perlin.c tga.c 
	gcc -std=c99 -pedantic -lm -o perlin fake_perlin.c tga.c

perlin2: fake_perlin2.c tga.c
	gcc -std=c99 -pedantic -lm -o perlin fake_perlin2.c tga.c

perlin3: fake_perlin3.c tga.c geom2.c v3.c
	gcc -std=c99 -pedantic -lm -lSDL -lGL -lglut -o perlin fake_perlin3.c tga.c geom2.c v3.c

4k: all 
	strip -s -R .comment -R .gnu.version intro 
	./sstrip intro 
	cp unpack.header 4k 
	gzip -cn9 intro >> 4k 
	chmod +x 4k
	ls -l 4k


intro.o: intro.c 
	$(CC) intro.c

v3.o: v3.h v3.c
	$(CC) v3.c

flower.o: shaders.h flower.c 
	$(CC) flower.c

shaders.h: pixel vertex
	./incstr.sh g_fragment_shader pixel > shaders.h
	./incstr.sh g_vertex_shader vertex >> shaders.h

clean: 
	rm -f 4k intro intro.o v3.o flower.o shaders.h

run: all
	./intro

tags:
	etags *.c *.h
