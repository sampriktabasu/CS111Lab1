# Pipe Up

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
