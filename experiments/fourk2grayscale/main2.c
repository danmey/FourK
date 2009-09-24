#include "tga.h" 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main(int argc, char **argv)
{
	char *bytes=0;
	char buf=0;
	char *outfile=0; 
	
	unsigned int size=0, readsize = 69175;
	double result = sqrt((double)readsize);
	unsigned int width=(unsigned int)result, height=(unsigned int)result;

	printf("width: %d heigth: %d square: %d\n", width,height,width*height);
	printf("shortsize: %d\n",sizeof(short));

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
	bytes = (char *)malloc((size_t)readsize);

	while((buf=fgetc(file))!=EOF)
	{
		if(size>=readsize) {
		printf("buffer size exceeded\n");
		free((void *)outfile);
		free((void *)bytes);
		fclose(file);
		return 1;
		}
		bytes[size]=buf;
		size++;
	}
	fclose(file);
	
	tga_save(outfile, bytes, width*height, (short)width, (short)height);

	free((void *)bytes);
	free((void *)outfile);

	return 0;
}
