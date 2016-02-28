
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
#include "command.h"
void yyerror(const char * s);
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
		printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
    | command_and_args PIPE {
        printf("   Yacc: Pipe\n");
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
               printf("   Yacc: insert argument \"%s\"\n", $1);

	       Command::_currentSimpleCommand->insertArgument( $1 );\
	}
	;

command_word:
	WORD {
               printf("   Yacc: insert command \"%s\"\n", $1);
	       
	       Command::_currentSimpleCommand = new SimpleCommand();
	       Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_list:
    iomodifier
    | iomodifier_list iomodifier
    |
    ;

iomodifier:
	GREAT WORD {
		printf("   Yacc: direct output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
	}
    | GREATGREAT WORD {
        printf("   Yacc: append output \"%s\"\n", $2);
        Command::_currentCommand._outFile = $2;
    }
    | LESS WORD {
        printf("   Yacc: direct input \"%s\"\n", $2);
        Command::_currentCommand._inFile = $2;
    }
    | GREATAND WORD {
        printf("   Yacc: direct error \"%s\"\n", $2);
        Command::_currentCommand._errFile = $2;
    }
    | GREATGREATAND WORD {
        printf("   Yacc: append error \"%s\"\n", $2);
        Command::_currentCommand._errFile = $2;
    }
	;

background:
    AMPERSAND {
        printf("   Yacc: background\n");
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

#if 0
main()
{
	yyparse();
}
#endif
