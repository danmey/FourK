#include "alloc.h"




void alloc_init(alloc_t* alloc, int size)
{
  alloc->size = size;
  alloc->index = 0;
}

void* alloc_new(alloc_t* alloc)
{
  void* obj = &alloc->ptr[alloc->index];
  alloc->index+=alloc->size;
  return obj;
}

void* alloc_end(alloc_t* alloc)
{
  return &alloc->ptr[alloc->index];
}

void* alloc_begin(alloc_t* alloc)
{
  return &alloc->ptr[0];
}

/*
void* alloc_at(alloc_t* alloc, int index)
{
  return &alloc->ptr[index*alloc->size];
}

int alloc_count(alloc_t* alloc)
{
  return alloc->index / alloc->size;
}

*/
