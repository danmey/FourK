// FourK - Concatenative, stack based, Forth like language optimised for 
//        non-interactive 4KB size demoscene presentations.

// Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
#include <stdio.h>
#include <math.h>
#include <GL/gl.h>
#include <GL/glut.h>
#include "SDL/SDL.h"

#include "matrix.h"
#include "alloc.h"
#include "stack.h"
#include "run.h"


#define M_PI 3.14159265
//#define UNIT 20.0f
#define UNIT_CONV(_x) ((float)_x)
#define RADIUS_FIXUP(_r,_t) (((float)(_r))/(cos(1.0f*M_PI/((float)(_t)))*2.0f))
#define UNIT_RADIUS_FIXUP(_r,_t) UNIT_CONV(RADIUS_FIXUP((_r),(_t)))

#define M(_mat) ((float*)_mat)

enum prim_type_e { Cylinder, Box };

// Structure holding primitive attributes
typedef struct
{
  float top_radius;
  float bottom_radius;
  float height;
  float shift_x,shift_y,shift_z;
  float rot_x, rot_y, rot_z;
  float col_r, col_g, col_b;
  float scale_y;
  int visibility;
  int hidden;
  int tess;
  
} prim_atts_t;

typedef struct {
  int pp1, pp2; // :)
} joint_t;


  
typedef struct
{
  matrix trans;
  prim_atts_t atts;
} prim_t;

void att_print(prim_atts_t* atts)
{
  printf("-----------\n"
	 "top_radius: %f\n"
	 "bottom_radius: %f\n"
	 "height: %f\n"
	 "visibility: %d\n"
	 "tess: %d\n",
	 atts->top_radius,
	 atts->bottom_radius,
	 atts->height,
	 atts->visibility,
	 atts->tess);
}

alloc_t primitive_alloc;
stack_t primitive_stack;
joint_t joint;

void default_primitive_atts(prim_atts_t* atts)
{
  atts->top_radius = 0;//UNIT;
  atts->bottom_radius = 0;//UNIT;
  atts->height = 0;//2.0f*UNIT;
  atts->visibility = 63;
  atts->rot_x = 0.0f;
  atts->rot_y = 0.0f;
  atts->shift_x = 0.0f;
  atts->shift_y = 0.0f;
  atts->shift_z = 0.0f;
  atts->tess = 30;
  atts->hidden = 0;
  atts->col_r = ((float)0xF0)/255.0f;
  atts->col_g = ((float)0x80)/255.0f;
  atts->col_b = 0.0;
  atts->scale_y = 64.0;
}

void new_primitive()
{
  joint.pp1 = 0;
  joint.pp2 = 0;
  prim_t* new_prim = alloc_new(&primitive_alloc);
  //  printf("new_primitive: %x\n", new_prim);
  //  printf("+alloc_end: %x\n", alloc_end(&primitive_alloc));

  //  printf("new_prim: %x\n", new_prim);
  default_primitive_atts(&new_prim->atts);
  matrix_identity(M(new_prim->trans));
  stack_push(&primitive_stack, new_prim);
  //  att_print(&new_prim->atts);
}


prim_t* current_primitive()
{
  return stack_top(&primitive_stack);
}

prim_t* previous_primitive()
{
  return stack_second(&primitive_stack);
}

void swap(float* a, float* b)
{
  float temp = *a;
  *a = *b;
  *b = temp;
}

void matrix_swap(matrix_t mat, int c1, int c2)
{
  for(int i=0; i<4; i++)
    {
      swap(&mat[i*4+c1], &mat[i*4+c2]);
    }
  swap(&mat[c1*4+3], &mat[c2*4+3]);
}

void prim_pivot_point_transform(prim_t* prim,
				int pp, matrix_t mat,
				int inverse)
{
  switch(Cylinder) { // would you mind? :P
  case Cylinder : 
    switch(pp) {
    case 0 :
      {
	matrix_identity(mat);
	return;
      }
    case 1 :
    case 2 :
      {
 	float h2 = prim->atts.height/(2.0f);
	if ( pp == 1 )
	  h2 = h2*-1.0f;
	if ( inverse )
	  h2 = h2*-1.0f;
	matrix_translate(0, 0, h2, mat);
	return;
      }
    }
  }
}

void do_transformation()
{
  prim_t* curr_prim = current_primitive();
  prim_t* prev_prim = previous_primitive();
  matrix temp, rota;
  matrix mat_pp1, mat_pp2, mat_pos;
  matrix mat_pos2, mat_rot, mat_rotpos, mat_final;

  prim_pivot_point_transform(prev_prim, joint.pp1, M(mat_pp1), 0);
  prim_pivot_point_transform(curr_prim, joint.pp2, M(mat_pp2), 1);

  matrix_translate(UNIT_CONV(curr_prim->atts.shift_x),
		   UNIT_CONV(curr_prim->atts.shift_y),
		   UNIT_CONV(curr_prim->atts.shift_z), M(mat_pos));
      
  matrix_multiply(M(mat_pos2), M(mat_pos), M(mat_pp2));

  matrix_rotation(curr_prim->atts.rot_x,
		  curr_prim->atts.rot_y,
		  curr_prim->atts.rot_z, M(mat_rot));

  matrix_multiply(M(mat_rotpos), M(mat_pos2), M(mat_rot));
  matrix_multiply(M(mat_rotpos), M(mat_rotpos), M(mat_pp1));  //  matrix_multiply(M(mat_rotpos), M(mat_rotpos), M(prev_prim->trans));
  //curr_prim++;
  for(prim_t* p = curr_prim;
      p < (prim_t*)alloc_end(&primitive_alloc);
      ++p)
    {
      matrix_multiply(M(p->trans), M(p->trans), M(mat_rotpos));
      matrix_multiply(M(p->trans), M(p->trans), M(prev_prim->trans));
    }  
}

#include "intro.c"

//byte* vm_word_tab[2];
void robots_init()
{
  //alloc_init(&matrix_alloc, sizeof(matrix));
  alloc_init(&primitive_alloc, sizeof(prim_t));
  stack_init(&primitive_stack);
  //  printf("init: %x\n", alloc_begin(&primitive_alloc));

  //  new_primitive();
  vm_init(main_dict, _vm_word_tab_);
  vm_run(_vm_word_tab_[VM_ENTRY_WORD].b);
}

void draw_scene()
{
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glFrustum(-1.00f, 1.00f,-.66,0.66f,1.1f,1000);
  glShadeModel(GL_FLAT);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  
  static float rot3=0*3.1415/2.4;
  rot3+=0.005f;

  gluLookAt(6*20.0f*sin(rot3),6*20.0f*cos(rot3),60.0*1.0f, 
  	    0.0f,0.0f,0.0f,
  	    0.0f,0.0f,1.0f);
  /*   gluLookAt(-30*sin(rot3),-30*cos(rot3),80.0, 
  	    0.0f,-30.0f,80.0f,
  	    0.0f,-1.0f,0.0f);
   */
  //  static 
  float rot2=0.0f;
  
  float pos[] = {1,1, 0};
  float diff[] = { 0xF0/(float)255, 0x80/(float)255,0, 1.0 };
  float col1[] = {0, 0, 0, 1};
  float col2[] = {1, 1, 1, 1};


  glEnable(GL_LIGHT1);							// Enable Light One
  glEnable(GL_LIGHTING);		// Enable Lighting
  glDisable(GL_CULL_FACE);

  glLightfv(GL_LIGHT1, GL_DIFFUSE, col2);
  //  glLightfv(GL_LIGHT1, GL_DIFFUSE, diff);
  ///  glLightfv(GL_LIGHT1, GL_POSITION, pos);			// Position The Light
  glEnable(GL_COLOR_MATERIAL);
  glEnable(GL_NORMALIZE);
  glColorMaterial(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE);
  glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, col2);
  glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, col1);

  static GLUquadricObj* quadric[4] = {NULL};
  glMatrixMode(GL_MODELVIEW);
  //  printf("%d\n", alloc_count(&prim_alloc));
  for(prim_t* p = alloc_begin(&primitive_alloc);
      p != (prim_t*)alloc_end(&primitive_alloc);
      ++p)
    {
      //      printf("drawn: %x\n", p);
      //      printf("alloc_end: %x\n", alloc_end(&primitive_alloc));
      if ( p->atts.hidden ) continue;
      glColor4f(p->atts.col_r, p->atts.col_g, p->atts.col_b, 1);

      glPushMatrix();
      if ( p != (prim_t*)primitive_alloc.ptr )
	glMultMatrixf(M(p->trans));
      
      glTranslatef(0,0,-0.5*UNIT_CONV(p->atts.height));
      if ( quadric[0] == NULL )
	{
	  
	  quadric[0] = gluNewQuadric();
	  quadric[1] = gluNewQuadric();
	  quadric[2] = gluNewQuadric();
	  quadric[3] = gluNewQuadric();
	}
      glScalef(1,p->atts.scale_y/64.0,1);
      glRotatef(360.0/(float)p->atts.tess/2, 0,0,1);
      gluQuadricDrawStyle(quadric[0], GLU_FILL);
      gluQuadricDrawStyle(quadric[1], GLU_FILL);
      gluQuadricDrawStyle(quadric[2], GLU_FILL);
      gluQuadricDrawStyle(quadric[3], GLU_FILL);
      gluQuadricNormals(quadric[0], GLU_FLAT);
      gluQuadricNormals(quadric[1], GLU_FLAT);
      gluQuadricNormals(quadric[2], GLU_FLAT);
      gluQuadricNormals(quadric[3], GLU_FLAT);
      gluCylinder(quadric[0],
		  UNIT_RADIUS_FIXUP(p->atts.bottom_radius,p->atts.tess),
		  UNIT_RADIUS_FIXUP(p->atts.top_radius,p->atts.tess),
		  UNIT_CONV(p->atts.height),
		  p->atts.tess,
		  1);

      gluQuadricOrientation(quadric[1], GLU_INSIDE);
      gluDisk(quadric[1],0,UNIT_RADIUS_FIXUP(p->atts.bottom_radius, p->atts.tess),p->atts.tess,2);
      glTranslatef(0,0,UNIT_CONV(p->atts.height));
      gluDisk(quadric[2],0,UNIT_RADIUS_FIXUP(p->atts.top_radius,p->atts.tess),p->atts.tess,2);
      glPopMatrix();
    }
}

int _start()
{
  
  
  SDL_SetVideoMode(800,600,0,SDL_OPENGL);
  SDL_ShowCursor(SDL_DISABLE);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glEnable(GL_DEPTH_TEST);
  glClearColor(0,0,1.0, 0.0);
  glClear(GL_DEPTH_BUFFER_BIT|GL_COLOR_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glLoadIdentity();

  SDL_Event event;
  robots_init();
  do
    {
      glClear(GL_DEPTH_BUFFER_BIT|GL_COLOR_BUFFER_BIT);      
      draw_scene();
      SDL_GL_SwapBuffers();
      SDL_PollEvent(&event);
      if (event.type==SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE ) break;
    } while (1);
  SDL_Quit();
  __asm ( \
  "movl $1,%eax\n" \
  "xor %ebx,%ebx\n" \
  "int $128\n" \
  );

}
