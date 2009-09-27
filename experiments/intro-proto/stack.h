#ifndef STACK_H
#define STACK_H

#define MAX_STACK (512*1024)



typedef struct {
  void* ptr[MAX_STACK];
  int index;
} stack_t;




void stack_init(stack_t* stack);
void stack_push(stack_t* stack, void* object);
void* stack_pop(stack_t* stack);
void* stack_top(stack_t* stack);
void* stack_second(stack_t* stack);

#endif
