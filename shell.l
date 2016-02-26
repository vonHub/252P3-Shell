
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"

static void yyunput (int c, char *buf_ptr);

void myunputc(int c) {
    unput(c);
}

%}

%%

\n 	{
        printf("Newline\n");
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
        printf("Space or tab\n");
    }	

">" 	{
        printf("Great\n");
		return GREAT;
	}

">>"    {
        printf("GreatGreat\n");
        return GREATGREAT;
    }

"|" {
        printf("Pipe\n");
        return PIPE;
    }

"&" {
        printf("Ampersand\n");
        return AMPERSAND;
    }

"<" {
        printf("Less\n");
        return LESS;
    }

">&"    {
        printf("GreatAnd\n");
        return GREATAND;
    }

">>&"   {
        printf("GreatGreatAnd\n");
        return GREATGREATAND;
    }
    
[^ \t\n][^ \t\n]*  {
		/* Assume that file names have only alpha chars */
		yylval.string_val = strdup(yytext);
        printf("Word\n");
		return WORD;
	}
