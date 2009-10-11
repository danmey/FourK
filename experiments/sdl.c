#include <dlfcn.h>
#include <stdio.h>
/* It is a minimal SDL stub */

int main()
{
  printf("%x\n", dlopen("libSDL.so",1));
}
