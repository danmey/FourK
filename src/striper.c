#include <stdio.h>

char buffer[1024*1024];
char* begx = "BEGX";
char* endx = "ENDX";

int main(int argc, char* argv[])
{
  FILE* f = fopen(argv[1], "rb");
  if ( f ) {
    int size = fread(buffer, 1, 1024*1024, f);
    fclose(f);
    int i;
    for(i=0; i<size-4; ++i)
      if ( *(unsigned int*)begx ==  *(unsigned int*)&buffer[i] ) {
	while( i < size-4 ) {
	  if ( *(unsigned int*)endx ==  *(unsigned int*)&buffer[i] ) 
	    break;
	  buffer[i] = 0;
	  i++;
	}
      }
    f = fopen(argv[1], "wb");
    fwrite(buffer, size, 1, f);
    fclose(f);
  }
  return 0;
}
