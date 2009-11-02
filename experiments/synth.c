#include "SDL/SDL.h"
#include "sys/soundcard.h"
#include "fcntl.h"
#include "sys/ioctl.h"
#include "unistd.h"
#include <math.h>

short audio_buffer[8192];

int main()
{
  SDL_Event event;
  int i;
  for(i=0; i<8192; ++i)
    {
      audio_buffer[i] = 32275.0*sinf((float)i*2.0*3.1415/8192.0*200.0);
    }

  int audio_fd = open("/dev/adsp1", O_WRONLY, 0);
  i=AFMT_S16_LE;

  printf("$%x const SNDCTL_DSP_SETFMT\n", SNDCTL_DSP_SETFMT);
  printf("$%x const SNDCTL_DSP_CHANNELS\n", SNDCTL_DSP_CHANNELS);
  printf("$%x const SNDCTL_DSP_SETFMT\n", SNDCTL_DSP_SETFMT);
  printf("$%x const SNDCTL_DSP_SPEED\n", SNDCTL_DSP_SPEED);
  printf("$%x const SNDCTL_DSP_SYNC\n",SNDCTL_DSP_SYNC);

  ioctl(audio_fd,SNDCTL_DSP_SETFMT,&i);
  i=1;
  ioctl(audio_fd,SNDCTL_DSP_CHANNELS,&i);
  i=11024;
  ioctl(audio_fd,SNDCTL_DSP_SPEED,&i);

  
  do
    {
      ioctl(audio_fd,SNDCTL_DSP_SYNC);
      write(audio_fd,audio_buffer,8192);
      SDL_PollEvent(&event);
    } while (event.type!=SDL_KEYDOWN);
  float x = 1.0;
  for(i=0; i < 20; ++i )
    x += 0.1;
  float y = 2.0;
  
  return x < y;
}
