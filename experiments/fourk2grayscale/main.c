#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	char *bytes=0;
	char buf=0;
	char *outfile=0; 
	
	unsigned int size=0;
	unsigned int width=0;
	unsigned int readsize = 69175; /* the actual size of the buffer*/

	FILE *file=0;

	/* png structs */
	png_structp write_ptr;
	png_infop info_ptr;

	if(!argc) {
	printf("Usage: <src-file>\n");
	return 1;
	}
	/* outfilename = srcfile + \0 + .png */
	outfile = (char *)malloc((strlen(argv[1])+1)+4);
	sprintf(outfile, "%s.png", argv[1]);

	/* let's assume we don't read files larger than 4096 bytes.. */
        /* I was too lazy to include a size check */	
	file = fopen(argv[1], "r");
	if(!file) return 1;
	bytes = (char *)malloc((size_t)readsize);

	while((buf=fgetc(file))!=EOF)
	{
		if(size>=4096) {
		printf("buffer size exceeded\n");
		free((void *)outfile);
		free((void *)bytes);
		fclose(file);
		return 1;
		}
		bytes[size]=buf;
		size++;
	}
	width = size/100;

	fclose(file);
	file = fopen(outfile, "wb");
	if(!file) return (ERROR);
	
	write_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING,
			png_voidp_NULL, png_error_ptr_NULL,
			png_error_ptr_NULL);
	if(!write_ptr) return (ERROR);
	
       	info_ptr = png_create_info_struct(write_ptr);
	if(!info_ptr) {
	png_destroy_write_struct(&write_ptr,(png_infopp)NULL);
	return (ERROR);
	}
	
	png_set_IHDR(write_ptr, info_ptr,width, 100, 8, 
				PNG_COLOR_TYPE_GRAY
				PNG_INTERLACE_NONE,
				PNG_COMPRESSION_TYPE_DEFAULT,
				PNG_FILTER_TYPE_DEFAULT);

	

	png_init_io(write_ptr, file);
	png_destroy_write_struct(&write_ptr,(png_infopp)NULL);
	free((void *)bytes);
	free((void *)outfile);

	return 0;
}
