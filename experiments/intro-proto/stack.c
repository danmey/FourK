#include "stack.h"




void stack_init(stack_t* stack)
{
  stack->index =0;
}

void stack_push(stack_t* stack, void* object)
{
  stack->ptr[stack->index] = object;
  stack->index++;
}

void* stack_pop(stack_t* stack)
{
  void* val = stack_top(stack);
  stack->index--;
  return val;
}

void* stack_top(stack_t* stack)
{
  return stack->ptr[stack->index-1];
}

void* stack_second(stack_t* stack)
{
   return stack->ptr[stack->index-2];
}

