#include "tga.h"
#include <stdio.h>

typedef struct {
   char  idlength;
   char  colourmaptype;
   char  datatypecode;
   short int colourmaporigin;
   short int colourmaplength;
   char  colourmapdepth;
   short int x_origin;
   short int y_origin;
   short width;
   short height;
   char  bitsperpixel;
   char  imagedescriptor;
} TGAHEADER;



int tga_save(char* filename,char* data,unsigned int data_size,short width,short height)
{
FILE* fp = fopen(filename,"wb");
unsigned int i = 0; //iterator

if(fp==NULL)return -1;

   //header save
   putc(0,fp);
   putc(0,fp);
   putc(2,fp);                         /* uncompressed RGB */
   putc(0,fp); putc(0,fp);
   putc(0,fp); putc(0,fp);
   putc(0,fp);
   putc(0,fp); putc(0,fp);           /* X origin */
   putc(0,fp); putc(0,fp);           /* y origin */
   putc((width & 0x00FF),fp);
   putc((width & 0xFF00) / 256,fp);
   putc((height & 0x00FF),fp);
   putc((height & 0xFF00) / 256,fp);
   putc(32,fp);                        /* 24 bit bitmap */
   putc(0,fp);

   // data save
   for(i=0;i<data_size;i++,putc(data[i],fp));

   fclose(fp);
}
