#include <stdio.h>
#include <sys/syscall.h>

int uselib(const char* name)
{
  int r;
  asm(	 "movl $134,%%eax\n"
	 "int $128\n" 
	 : "=a"(r)
	 : "b"(name)
	 );
  return r;
}

void _start()
{
  printf("%d\n", uselib("/lib/libdl.so.2"));
  __asm ( \
	 "movl $1,%eax\n"			\
	 "xor %ebx,%ebx\n"			\
	 "int $128\n"				\
	  );
}
