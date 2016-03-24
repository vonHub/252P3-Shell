/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 * cmd [arg]* [ | cmd [arg]* ]* [ [> filename] [< filename] [ >& filename] [>> filename] [>>& filename] ]* [&]
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE GREATGREAT PIPE AMPERSAND
%token  LESS GREATAND GREATGREATAND

%union	{
		char   *string_val;
	}

%{
//#define yylex yylex
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include <dirent.h>
#include "command.h"
void yyerror(const char * s);
void expandWildcardsIfNecessary(char * arg);
int cmpr(const void *a, const void *b);
int yylex();

%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command 
	;

command:
    simple_command
    ;

simple_command:	
	command_and_args iomodifier_list background NEWLINE {
		// printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
    | command_and_args PIPE {
        // printf("   Yacc: Pipe\n");
    }
	| NEWLINE 
	| error NEWLINE { yyerrok; }
	;

command_and_args:
	command_word argument_list {
		Command::_currentCommand.
			insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;

argument_list:
	argument_list argument
	| /* can be empty */
	;

argument:
	WORD {
               // printf("   Yacc: insert argument \"%s\"\n", $1);
           expandWildcardsIfNecessary($1);
	}
	;

command_word:
	WORD {
               // printf("   Yacc: insert command \"%s\"\n", $1);
	       
	       Command::_currentSimpleCommand = new SimpleCommand();
	       Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_list:
    iomodifier
    | iomodifier_list iomodifier
    |
    ;

// Input, output, and error modifiers
iomodifier:
	GREAT WORD {
        // printf("   Yacc: direct output \"%s\"\n", $2);
        if (Command::_currentCommand._outFile == 0) {
		    Command::_currentCommand._outFile = $2;
        } else {
            printf("Ambiguous output redirect\n");
            Command::_currentCommand._error = 1;
        }
	}
    | GREATGREAT WORD {
        // printf("   Yacc: append output \"%s\"\n", $2);
        if (Command::_currentCommand._outFile == 0) {
            Command::_currentCommand._outFile = $2;
            Command::_currentCommand._outAppend = 1;
        } else {
            printf("Ambiguous output redirect\n");
            Command::_currentCommand._error = 1;
        }
    }
    | LESS WORD {
        // printf("   Yacc: direct input \"%s\"\n", $2);
        if (Command::_currentCommand._inFile == 0) {
            Command::_currentCommand._inFile = $2;
        } else {
            printf("Ambiguous input redirect\n");
            Command::_currentCommand._error = 1;
        }
    }
    | GREATAND WORD {
        // printf("   Yacc: direct error \"%s\"\n", $2);
        if (Command::_currentCommand._errFile == 0) {
            Command::_currentCommand._errFile = $2;
        } else {
            printf("Ambiguous error redirect\n");
            Command::_currentCommand._error = 1;
        }
    }
    | GREATGREATAND WORD {
        // printf("   Yacc: append error \"%s\"\n", $2);
        if (Command::_currentCommand._errFile == 0) {
            Command::_currentCommand._errFile = $2;
            Command::_currentCommand._errAppend = 1;
        } else {
            printf("Ambiguous error redirect\n");
            Command::_currentCommand._error = 1;
        }
    }
	;

background:
    AMPERSAND {
        // printf("   Yacc: background\n");
        Command::_currentCommand._background = 1;
    }
    | /* can be empty */
    ;
    

%%

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

void expandWildcardsIfNecessary(char * arg) {
    if (strchr(arg, '*') == NULL && strchr(arg, '?') == NULL) {
        Command::_currentSimpleCommand->insertArgument(arg);
        return;
    }
    char * reg = (char *)malloc(2 * strlen(arg) + 10);
    char * a = arg;
    char * r = reg;
    *r = '^'; r++;
    while (*a) {
        if (*a == '*') {
            *r = '.'; r++;
            *r = '*'; r++;
        } else
        if (*a == '?') {
            *r='.'; r++;
        } else
        if (*a == '.') {
            *r = '\\'; r++;
            *r = '.'; r++;
        } else {
            *r = *a; r++;
        }
        a++;
    }
    *r = '$'; r++;
    *r = 0;

    regex_t re;
    if (regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0) {
        perror("Wildcard error");
        return;
    }

    DIR * dir = opendir(".");
    if (dir == NULL) {
        perror("opendir error");
        return;
    }

    struct dirent * ent;
    int maxEntries = 20;
    int nEntries = 0;
    char ** array = (char **)malloc(maxEntries * sizeof(char*));

    while ( (ent = readdir(dir)) != NULL) {
        if (regexec(&re, ent->d_name, (size_t)0, NULL, 0) == 0) {
            if (nEntries == maxEntries) {
                maxEntries *= 2;
                array = (char **)realloc(array, maxEntries * sizeof(char *));
            }
            array[nEntries] = strdup(ent->d_name);
            nEntries++;
        }
    }

    closedir(dir);

    qsort(array, nEntries, sizeof(char *), cmpr);

    for (int i = 0; i < nEntries; i++) {
        Command::_currentSimpleCommand->insertArgument(array[i]);
    }
}

int cmpr(const void *a, const void *b) {
    return strcmp(*(char **)a, *(char **)b);
}

#if 0
main()
{
	yyparse();
}
#endif
