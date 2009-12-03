%{
#include <strings.h>
#include <ctype.h>
#include <stdlib.h>

#define NAME_LEN 5


struct Symbol {
 char name [NAME_LEN];
 unsigned int count; // added count of 
 unsigned int bcount; // count of the symbol at the beginning of words
 unsigned int ecount; // count of the symbol at the end of words 
 unsigned int mcount; // count of the symbol in a word
};
typedef struct Symbol Tymbol;

Tymbol *allSyms;
unsigned int allSymsSize;
unsigned int used;

int search(char *name)
{
	unsigned int i=0, h=0;	
	
	for(i=0;i<strlen(name);i++)
	h=(h*26+(tolower(name[i])-96))%allSymsSize;

	while(i<allSymsSize)
	{
		if(allSyms[h].name[0]=='\0')
		{
			for(i=0;i<5;i++)
			allSyms[h].name[i]=name[i]; 

			allSyms[h].count=1;
			allSyms[h].bcount=0;
			allSyms[h].ecount=0;
			allSyms[h].mcount=0;
			used++;

			return h;
		}
		else
		{
			if(strcasecmp(name, allSyms[h].name)==0) {
			allSyms[h].count++;
			return h;
			}
		}
		h=(((h+13)%allSymsSize)+1)%allSymsSize;
		i++;
	}
	return -1;
}

int search_withb(char *name)
{
	int i;

	if(strlen(name)>0)
	{
		while(name[i]!='\0')
		{
			if(isalpha(name[i])) break;
			i++;
		}
		name+=i;

		if((i=search(name))>=0)
		allSyms[i].bcount++;
	}
}

int search_withe(char *name)
{
	int i;
	if(strlen(name)>0)
	{
		while(name[i]!='\0'){
		if(isblank(name[i])) break;
		i++;
		}
		name[i]='\0';
		
		if((i=search(name))>=0)
		allSyms[i].ecount++;
	}
}

int search_withm(char *name)
{
	int i;
	if((i=search(name))>=0)
	allSyms[i].mcount++;
	
}

%}
   
     int num_chars = 0;

CHAR [a-zA-Z]
OTHER [^a-zA-Z]
WHITE [:blank:]

%% 
{CHAR}{1}      { search(yytext); num_chars++; }
{CHAR}{2}      { search(yytext); REJECT; }
{CHAR}{3}      { search(yytext); REJECT; }
{CHAR}{4}      { search(yytext); REJECT; }
{CHAR}{5}      { search(yytext); REJECT; }


{OTHER}*	{   }

%% 

int ecompare(const void *ptrA, const void *ptrB)
{
	const Tymbol *left=ptrA;
        const Tymbol *right=ptrB;
	
	if((*left).count == (*right).count) return 0;
	if((*left).count < (*right).count) return -1;
	if((*left).count > (*right).count) return 1;
}



int main (int argc, char **argv)
{
	unsigned int i=0, avg=0, k=0;

	if(argc>1)
	{
		for(i=0;i<argc;i++)
		{
			if(strcmp(argv[i], "--help")==0
			   || strcmp(argv[i], "-h")==0)
			{
				printf("-h, --help Displays this\n");
				printf("-da  display all contents of the table\n");
				return 0;
			}
		}
	}

	used = 0;
	allSymsSize = 999983; // a big prime
	allSyms=(Tymbol *)malloc(allSymsSize*sizeof(Tymbol));
	
	for(i=0;i<allSymsSize;i++)
	allSyms[i].name[0]='\0';

	yylex();

	for(i=0;i<allSymsSize;i++)
	if(allSyms[i].name[0]!='\0')
	avg+=allSyms[i].count;

	avg=avg/used;
	if(argc>1) 
	{
		for(i=1;i<argc;i++)
		{
			if(strcmp(argv[i], "-da")==0)
			avg=0;
		}
	}
	printf("Total chars: %d\n", num_chars);
	printf("Average count: %d\n", avg);
	printf("Total added entries in table: %d\n", used);
	printf("Usage of table: %3.1f%\n", 100.0*(((double)used)/((double)allSymsSize)));
	printf("Table: \n");
		
	// sorting
	qsort(allSyms, allSymsSize, sizeof(Tymbol), ecompare);

	for(i=0;i<allSymsSize;i++)
	{
		if((allSyms[i].count>avg) && (allSyms[i].name[0]!='\0'))
		{
			k=0;
			while(allSyms[i].name[k]!='\0'){
			putchar(tolower(allSyms[i].name[k]));
			k++;
			}
			printf(":%d\n",allSyms[i].count);
		}
	}
	free((void *)allSyms);
}
