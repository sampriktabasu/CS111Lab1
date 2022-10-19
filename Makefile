pipe.c                                                                                              0000644 0001750 0001750 00000005606 14323716123 010432  0                                                                                                    ustar   cs111                           cs111                                                                                                                                                                                                                  #include <stdio.h>
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
                                                                                                                          README.md                                                                                           0000644 0001750 0001750 00000000705 14323714005 010600  0                                                                                                    ustar   cs111                           cs111                                                                                                                                                                                                                  # Pipe Up

Low level code that is performed by the pipe (|) operator in shells to direct input and output amongst given command line arguments.

## Building

To build the program and make the executable, use the command:
make 

## Running

Example run:
./pipe ls cat wc 
expects to return the equivalent to running...
ls | cat | wc
which returns something that looks like
8 8 73

## Cleaning up

Clean up binary files by running the command:
make clean
                                                           test_lab1.py                                                                                        0000644 0001750 0001750 00000004726 14323337221 011561  0                                                                                                    ustar   cs111                           cs111                                                                                                                                                                                                                  import pathlib
import re
import subprocess
import unittest

class TestLab1(unittest.TestCase):

    def _make():
        result = subprocess.run(['make'], capture_output=True, text=True)
        return result

    def _make_clean():
        result = subprocess.run(['make', 'clean'],
                                capture_output=True, text=True)
        return result

    @classmethod
    def setUpClass(cls):
        cls.make = cls._make().returncode == 0

    @classmethod
    def tearDownClass(cls):
        cls._make_clean()

    def test_3_commands(self):
        self.assertTrue(self.make, msg='make failed')
        cl_result = subprocess.run(('ls | cat | wc'),
                                capture_output=True, shell=True)
        pipe_result = subprocess.check_output(('./pipe', 'ls', 'cat', 'wc'))
        self.assertEqual(cl_result.stdout, pipe_result,
            msg=f"The output from ./pipe should be {cl_result.stdout} but got {pipe_result} instead.")
        self.assertTrue(self._make_clean, msg='make clean failed')
    
    def test_no_orphans(self):
        self.assertTrue(self.make, msg='make failed')
        subprocess.call(('strace', '-o', 'trace.log','./pipe','ls','wc','cat','cat'))
        ps = subprocess.Popen(['grep','-o','clone(','trace.log'], stdout=subprocess.PIPE)
        out1 = subprocess.check_output(('wc','-l'), stdin=ps.stdout)
        ps.wait()        
        ps.stdout.close()
        ps = subprocess.Popen(['grep','-o','wait','trace.log'], stdout=subprocess.PIPE)
        out2 = subprocess.check_output(('wc','-l'), stdin=ps.stdout)
        ps.wait()  
        ps.stdout.close()
        out1 = int(out1.decode("utf-8")[0])
        out2 = int(out2.decode("utf-8")[0])
        if out1 == out2 or out1 < out2:
            orphan_check = True
        else:
            orphan_check = False
        self.assertTrue(orphan_check, msg="Found orphan processes")
        subprocess.call(['rm', 'trace.log'])
        self.assertTrue(self._make_clean, msg='make clean failed')
    
    def test_bogus(self):
        self.assertTrue(self.make, msg='make failed')
        pipe_result = subprocess.run(('./pipe', 'ls', 'bogus'), stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)
        self.assertTrue(pipe_result.returncode, msg='Bogus argument should cause an error, expect nonzero return code.')
        self.assertNotEqual(pipe_result.stderr, '', msg='Error should be reported to standard error.')
        self.assertTrue(self._make_clean, msg='make clean failed')

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          