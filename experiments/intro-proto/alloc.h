#ifndef ALLOC_H
#define ALLOC_H

#define MAX_ALLOC_BYTES (512*1024)


typedef struct
{

  int size;
  int index;
  unsigned char ptr[MAX_ALLOC_BYTES];
} alloc_t;





void alloc_init(alloc_t* alloc, int size);
void* alloc_new(alloc_t* alloc);
void* alloc_end(alloc_t* alloc);
void* alloc_begin(alloc_t* alloc);

//void* alloc_at(alloc_t* alloc, int index);
//int alloc_count(alloc_t* alloc);

#endif
