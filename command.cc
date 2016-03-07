// Code completed in its current form by
// Christopher Von Hoene
// 3/6/16
// In submission of Part 2 of the shell project

/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>

#include "command.h"

SimpleCommand::SimpleCommand()
{
	// Create available space for 5 arguments
	_numOfAvailableArguments = 5;
	_numOfArguments = 0;
	_arguments = (char **) malloc( _numOfAvailableArguments * sizeof( char * ) );
}

void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numOfAvailableArguments == _numOfArguments  + 1 ) {
		// Double the available space
		_numOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				  _numOfAvailableArguments * sizeof( char * ) );
	}
	
	_arguments[ _numOfArguments ] = argument;

	// Add NULL argument at the end
	_arguments[ _numOfArguments + 1] = NULL;
	
	_numOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
    _outAppend = 0;
    _errAppend = 0;
    _error = 0;
}

void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numOfAvailableSimpleCommands == _numOfSimpleCommands ) {
		_numOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
			 _numOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}
	
	_simpleCommands[ _numOfSimpleCommands ] = simpleCommand;
	_numOfSimpleCommands++;
}

void
Command:: clear()
{
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}
		
		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inFile ) {
		free( _inFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
    _outAppend = 0;
    _errAppend = 0;
    _error = 0;
}

void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");
	
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
        printf("\n");
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inFile?_inFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );
	
}

void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numOfSimpleCommands == 0 ) {
		prompt();
		return;
	}

	// Print contents of Command data structure
    if (!_error) {
	    // print();
    } else {
        printf("Command encountered error, execution cancelled\n");
    }

	// Add execution here
	// For every simple command fork a new process
	// Setup i/o redirection
	// and call exec

    // Store normal inputs and outputs
    int defaultin = dup(0);
    int defaultout = dup(1);
    int defaulterr = dup(2);
    
    // Set up initial input
    int fdin;
    if (_inFile) {
        fdin = open(_inFile, O_RDONLY);
    } else {
        fdin = dup(defaultin);
    }
   
    // Set up error output
    int fderr;
    if (_errFile) {
        // Compute the correct mode
        int flag = O_WRONLY | O_CREAT;
        if (_errAppend) flag = flag | O_APPEND;
        else flag = flag | O_TRUNC;

        // Open the stream
        fderr = open(_errFile, flag, 0666);
    } else {
        fderr = dup(defaulterr);
    }
    dup2(fderr, 2);
    close(fderr);

    int ret;
    int fdout;

    // Loop through list of simple commands
    for (int i = 0; i < _numOfSimpleCommands; i++) {

        // Direct input properly
        dup2(fdin, 0);
        close(fdin);

        // Determine correct output
        if (i == _numOfSimpleCommands - 1) {

            // Last Simple Command
            if (_outFile) {
                // Compute the correct mode
                int flag = O_WRONLY | O_CREAT;
                if (_outAppend) flag = flag | O_APPEND;
                else flag = flag | O_TRUNC;

                // Open the output stream
                fdout = open(_outFile, flag, 0666);
            } else {
                fdout = dup(defaultout);
            }

        } else {

            // Not last simple command
            // Pipe the output to the next one
            int fdpipe[2];
            if (pipe(fdpipe) < 0) {
                perror("Pipe error:");
                exit(1);
            }
            fdout = fdpipe[1];
            fdin = fdpipe[0];

        }

        // Redirect output to determined file
        dup2(fdout, 1);
        close(fdout);

        // Duplicate this process
        ret = fork();
        
        if (ret == 0) {
            // Child process
            // Execute command
            execvp(_simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments);
            perror("Execvp error");
            _exit(1);
        } else if (ret > 0) {
            // Parent process
            // Go on to next simple command
        } else {
            // Fork returned an error
            perror("Fork error");
            exit(1);
        }
    } // End of for loop

    // Restore default inputs and outputs
    dup2(defaultin, 0);
    dup2(defaultout, 1);
    dup2(defaulterr, 2);
    close(defaultin);
    close(defaultout);
    close(defaulterr);

    // Wait until command termination if necessary
    if (!_background) {
        // Since this is the parent process
        // ret will contain the pid of the child process
        waitpid(ret, NULL, 0);
    }

	// Clear to prepare for next command
	clear();
	
	// Print new prompt
	prompt();
}

// Shell implementation

void
Command::prompt()
{
    if (isatty(0)) {
	    printf("myshell>");
	    fflush(stdout);
    }
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);

main()
{
	Command::_currentCommand.prompt();
	yyparse();
}

