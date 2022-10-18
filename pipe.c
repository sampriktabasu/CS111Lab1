#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>

// helper function to open a pipe
void  create_pipe(int *p) {
  if(pipe(p) == -1) {
    perror("pipe failure");
    exit(errno);
  }
  return;
}

// helper function to handle when a pipe is duplicated

void duplicate(int p, int dest) {
  if(dup2(p, dest) == -1) {
    exit(errno);
  }
  return;
}

// helper function to handle when a pipe is closed
void close_descriptor(int fd) {
  if(close(fd)== -1) {
    exit(errno);
  }
}



int main(int argc, char *argv[])
{

  // check for invalid arguments
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

  // loop through args
  for(int i = 1; i < argc; i++) {
    int pid = fork();
    if(pid < 0) {
      perror("fork failure");
      exit(ESRCH);
      return ESRCH;
    }
    if (pid == 0) {
      // handle child processes
      // handle middle arguments
      if ((i % 2) == 1) {
	duplicate(p2[0], STDIN_FILENO);
	if(i != (argc - 1)) {
	  duplicate(p1[1], STDOUT_FILENO);
	}
	close_descriptor(p1[0]);
	close_descriptor(p1[1]);
	close_descriptor(p2[0]);
      }
      else {
	duplicate(p1[0], STDIN_FILENO);
	if(i!= (argc-1)) {
	  duplicate(p2[1], STDOUT_FILENO);
	}
	close_descriptor(p1[0]);
	close_descriptor(p2[0]);
	close_descriptor(p2[1]);
      }

      int exec = execlp(argv[i], argv[i], NULL);
      if(exec == -1) {
	exec = errno;
	perror("execlp failure");
	return exec;
      }
    }
    // fork returns positive
    else {
      int status;
      wait(&status);
      if(WIFEXITED(status) && (WEXITSTATUS(status)!=0)) {
	perror("child process errored out");
	exit(WEXITSTATUS(status));
      }
      if(i % 2 == 1) {
	close_descriptor(p1[1]);
	close_descriptor(p2[0]);
	create_pipe(p2);
      }
      else {
	close_descriptor(p1[0]);
	close_descriptor(p2[1]);
	create_pipe(p1);
      }
      

    }
  }

 
  return 0;
}
