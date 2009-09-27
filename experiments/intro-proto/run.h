#ifndef RUN_H
#define RUN_H



typedef unsigned char byte;
typedef void (*vm_func)(byte**);

typedef struct
{
  byte* b;
} byte_code_t;

void vm_init(vm_func* core,byte_code_t* word_tab);
void vm_run(byte* bytecode);
int vm_pop_stack();
void vm_push_stack(int val);
void VMdef_lit(byte** bytecode);




#endif
