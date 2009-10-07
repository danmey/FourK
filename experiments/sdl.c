/* It is a minimal SDL stub */

int _start()
{
  SDL_SetVideoMode(800,600,0,SDL_OPENGL);
  /*  SDL_ShowCursor(SDL_DISABLE); */
  /*
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  */
  glEnable(GL_DEPTH_TEST);
  glClearColor(0,0,1.0, 0.0);
  glDisable(GL_CULL_FACE);

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
  /* Exit 
 __asm ( \
  "movl $1,%eax\n" \
  "xor %ebx,%ebx\n" \
  "int $128\n" \
  );
  */
}
