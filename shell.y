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
void expand(char * arg);
char * expandTildes(char * arg);
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
           expand($1);
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

void expand(char * arg) {

    // Expand tildes
    arg = expandTildes(arg);

    // Check if wildcards exist
    if (strchr(arg, '*') == NULL && strchr(arg, '?') == NULL) {
        // If not, no need for anything fancy
        Command::_currentSimpleCommand->insertArgument(arg);
        return;
    }

    // Open correct directory
    // No slashes means current directory
    // Preceding slash means absolute path
    // Slashes but not beginning means use part up
    //     to last slash
    // Then chop off the directory bit from the regex
    char * directory;
    char * start;

    int prepend = 1;
    int hidden = 1;

    if (strchr(arg, '/') == NULL) {
        directory = strdup(".");
        start = arg;
        prepend = false;    // Don't return preceded by dir name
    } else {
        directory = strdup(arg);
        char * c = directory + strlen(arg);
        while (*c != '/') {
            c--;
        }
        if (c != directory) {
            *c = '\0';
        }
        start = arg + (c - directory) + 1;
    }
    //printf("Directory: %s\n", directory);
    // 'Directory' will now hold a psuedo-regex.
    // We need to turn it into a real regex and
    // check every directory matching it.


    if (*start == '.') {
        hidden = 0;
        start++;
    }

    // Replace wildcards with regex counterparts
    char * reg = (char *)malloc(2 * strlen(start) + 10);
    char * a = start;
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

    // Now repeat for the directory name
    char * dirreg = (char *)malloc(2 * strlen(directory) + 10);
    a = directory;
    char * d = dirreg;
    *d = '^'; d++;
    while (*a) {

        a++;
    }
    *d = '$'; d++;
    *d = 0;

    // printf("Regular expression: %s\n", reg);

    // Convert arg into regular expression
    regex_t re;
    if (regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0) {
        perror("Wildcard error");
        return;
    }

    DIR * dir = opendir(directory);
    if (dir == NULL) {
        perror("opendir error");
        return;
    }

    // Create an array to put matches into
    struct dirent * ent;
    int maxEntries = 20;
    int nEntries = 0;
    char ** array = (char **)malloc(maxEntries * sizeof(char*));

    // Check for matches in directory files
    while ( (ent = readdir(dir)) != NULL) {
        // printf("Entry: %s\n", ent->d_name);
        if (regexec(&re, ent->d_name, (size_t)0, NULL, 0) == 0) {

            // Ignore hidden files
            if (*(ent->d_name) == '.' && hidden) continue;
            if (*(ent->d_name) != '.' && !hidden) continue;

            if (nEntries == maxEntries) {
                maxEntries *= 2;
                array = (char **)realloc(array, maxEntries * sizeof(char *));
            }

            array[nEntries] = strdup(ent->d_name);
            nEntries++;
        }
    }

    closedir(dir);

    // Sort alphanumerically
    qsort(array, nEntries, sizeof(char *), cmpr);

    // Add matches to arguments list
    for (int i = 0; i < nEntries; i++) {
        if (prepend) {
            char * result = strdup(directory);
            result = strcat(result, "/");
            char * final = (char *)malloc(sizeof(char) * (strlen(result) + strlen(array[i]) + 1));
            sprintf(final, "%s%s", result, array[i]);
            *(final + strlen(result) + strlen(array[i])) = '\0';
            Command::_currentSimpleCommand->insertArgument(final);
        } else {
            Command::_currentSimpleCommand->insertArgument(array[i]);
        }
    }
}

char * expandTildes(char * arg) {
    if (strcmp(arg, "~") == 0) {
        return getenv("HOME");
    } else if (*arg == '~' && *(arg + 1) == '/') {
        // Replace tilde with home directory
        char * home = getenv("HOME");
        char * buf = (char *)malloc(strlen(home) + strlen(arg));
        char * a = arg;
        char * b = buf;
        char * h = home;
        while (*a != '~') {
            *b++ = *a++;
        }
        a++;
        while (*h != '\0') {
            *b++ = *h++;
        }
        while (*a != '\0') {
            *b++ = *a++;
        }
        *b = '\0';
        printf("Result: %s\n", buf);
        return buf;
    } else {
        // Get tilde and name of other user
        // Then replace tilde with his home directory

    }
    return arg;
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
