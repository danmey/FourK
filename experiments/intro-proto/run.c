#include <stdio.h>
#include "stack.h"
#include "run.h"

stack_t vm_stack;


int vm_print_stack()
{
  for(int i=0; i<vm_stack.index;++i)
    {
      printf("%d ", vm_stack.ptr[i]);
    }
  printf("\n");
}
int vm_pop_stack()
{
  int val = (int)stack_top(&vm_stack);
  stack_pop(&vm_stack);
  return val;
}

void vm_push_stack(int val)
{
  stack_push(&vm_stack, (void*)(val));
}

void VMdef_lit(byte** bytecode)
{
  int val = *++( *(signed char**)bytecode);
  stack_push(&vm_stack, (void*)val);
}

void vm_plus(byte** bytecode)
{
  int val1 = (int)stack_top(&vm_stack);
  stack_pop(&vm_stack);
  int val2 = (int)stack_top(&vm_stack);
  stack_pop(&vm_stack);
  stack_push(&vm_stack, (void*)(val1+val2));
}

vm_func* vm_core;
byte_code_t* vm_word_tab;

void vm_init(vm_func* core, byte_code_t word_tab[])
{
  stack_init(&vm_stack);
  vm_core = core;
  vm_word_tab = word_tab;
}
extern byte test_word1[];
void vm_run(byte* bytecode)
{
  while(*bytecode != (byte)-1)
    {
      if ( *bytecode & 0x80 )
	//	printf("%d\n",vm_word_tab[-((int)(*(char*)bytecode))-2].b[0]);
	vm_run(vm_word_tab[-((int)(*(char*)bytecode))-2].b);
      ///	printf("%d\n",vm_word_tab[-((int)(*(char*)bytecode)-2)].b[0]);
      else    
	vm_core[*bytecode](&bytecode);
      bytecode++;
    }
}


//byte code[] = {  0, 123, 0, 10, 1, -1 };

/*
int main()
{
  vm_init();
  vm_run(code);
  printf("Execution result: %d\n", (int)stack_top(&vm_stack));
  return 0;
}
*/

