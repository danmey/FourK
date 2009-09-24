#include "tga.h" 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>


int main(int argc, char **argv)
{
	char *bytes=0;
	char buf=0;
	char *outfile=0; 
	

	struct stat buffer;
	unsigned int readsize;
	double result;
	unsigned int width, height;

	FILE *file=0;


	if(!argc) {
	printf("Usage: <src-file>\n");
	return 1;
	}
	/* outfilename = srcfile + \0 + .png */
	outfile = (char *)malloc((strlen(argv[1])+1)+4);
	sprintf(outfile, "%s.tga", argv[1]);

	/* let's assume we don't read files larger than 4096 bytes.. */
        /* I was too lazy to include a size check */	
	file = fopen(argv[1], "r");
	if(!file) return 1;
	
	fstat(fileno(file), &buffer);
	readsize = buffer.st_size;
	printf("size: %d\n", readsize);

	result = sqrt((double)readsize);
	width = result;
	height = result;

	bytes = (char *)malloc((size_t)readsize);

	fread(bytes, 1, readsize, file);
	fclose(file);
	
	tga_save(outfile, bytes, width*height, (short)width, (short)height);

	free((void *)bytes);
	free((void *)outfile);

	return 0;
}
