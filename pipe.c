#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>

// helper function to open a pipe accounting for failure
void  create_pipe(int *p) {
  if(pipe(p) == -1) {
    exit(errno);
  }
  return;
}

// helper function to handle when a pipe is duplicated accounting for failure
void duplicate(int p, int dest) {
  if(dup2(p, dest) == -1) {
    exit(errno);
  }
  return;
}

// helper function to handle when a pipe is closed accounting for failure
void close_descriptor(int fd) {
  if(close(fd)== -1) {
    exit(errno);
  }
}


int main(int argc, char *argv[])
{

  // check for invalid number of arguments
  if(argc <= 1) {
    perror("invalid # of arguments");
    // throw error exit code
    exit(EINVAL);
  }

  // TO BE ABLE TO HANDLE TWO ARGUMENTS AT A TIME, HAVE 2 PIPE BUFFERS
  // create the first pipe buffer
  int p1[2]; // 2 to hold blank from lecture
  create_pipe(p1);
  
  
  // create the second pipe buffer
  int p2[2];
  create_pipe(p2);

  // there's never input for the first command ... close stdin
  close_descriptor(p2[1]);

  // loop through all arguments 
  for(int i = 1; i < argc; i++) {
    int pid = fork();

    // if -1 account for fork failure, throw error
    if(pid < 0) {
      perror("fork failure");
      exit(errno);
      return errno;
    }
    // child processes 
    if (pid == 0) {
      if ((i % 2) == 1) {
	// take in input on the read end 
	duplicate(p2[0], STDIN_FILENO);
	// if the current argument is not the last one, continue redirecting output to the write end of the pipe
	if(i != (argc - 1)) {
	  duplicate(p1[1], STDOUT_FILENO);
	}
	// close file descriptor read & write ends
	close_descriptor(p1[0]);
	close_descriptor(p1[1]);
	close_descriptor(p2[0]);
      }
      else {
	// input reads from the read end of the pipe
	duplicate(p1[0], STDIN_FILENO);
	if(i!= (argc-1)) {
	  // ^^ redirect output 
	  duplicate(p2[1], STDOUT_FILENO);
	}
	// close pipe read and write ends
	close_descriptor(p1[0]);
	close_descriptor(p2[0]);
	close_descriptor(p2[1]);
      }

      // actually execute the current command (return error if it fails)
      // int exec = execlp(argv[i], argv[i], NULL);
      if(execlp(argv[i], argv[i], NULL) == -1) {
	// exec = errno;
	perror("failure executing a command");
	return errno;
      }
    }
    // parent process, fork returns positive
    else {
      int status;
      // actually wait for child processes to finish
      wait(&status);
      if(WIFEXITED(status) && (WEXITSTATUS(status)!=0)) {
	perror("child process errored out");
	exit(WEXITSTATUS(status));
      }
      // close write and read end and run next pipe (handles output)
      if(i % 2 == 1) {
	close_descriptor(p1[1]);
	close_descriptor(p2[0]);
	create_pipe(p2);
      }
      // close read and write end and run pipe (handles input)
      else {
	close_descriptor(p1[0]);
	close_descriptor(p2[1]);
	create_pipe(p1);
      }
    }
  }

  return 0;
}
