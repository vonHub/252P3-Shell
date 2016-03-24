
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
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
    }	

">" 	{
		return GREAT;
	}

">>"    {
        return GREATGREAT;
    }

"|" {
        return PIPE;
    }

"&" {
        return AMPERSAND;
    }

"<" {
        return LESS;
    }

">&"    {
        return GREATAND;
    }

">>&"   {
        return GREATGREATAND;
    }

\".+\"  {
        int length = strlen(yytext);
        char buf[length - 1];
        memcpy(buf, yytext + 1, length - 2);
        buf[length - 1] = '\0';
        // printf("Copied from quotes: %s\n", buf);
        yylval.string_val = strdup(buf);
        return WORD;
    }

[^ \t\n][^ \t\n]*  {
		/* Assume that file names have only alpha chars */
		yylval.string_val = strdup(yytext);
        //printf("Word\n");
		return WORD;
	}
