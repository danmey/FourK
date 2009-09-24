#pragma pack(1)
struct nlTGAHeader
{
        char text_size;
        char map_type;
        char data_type;
        short map_org;
        short map_length;
        char cmap_bits;
        short x_offset;
        short y_offset;
        short width;
        short height;
        char data_bits;
        char im_type;
};
#pragma pack()

//char*	loadTGA();
void	saveTGA(char *filename, char *bits, int h, int w);
//void save_tga(char *filename, int w, int h, char* bits);
int tga_save(char* filename,char* data,unsigned int data_size,short width,short height);
