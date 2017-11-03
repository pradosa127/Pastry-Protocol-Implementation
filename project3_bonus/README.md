DOS Project-3:  Pastry Algorithm

# 1. Team Members:

Pradosa Patnaik (UFID: 1288-9584)
Supraba Muruganantham (UFID: 9215-9813)
# 2. Code Submitted:

project3_bonus.ex

# 3. How To Run

To run Pastry algorithm using Full network topology the command is as follows:
 Compile the project from the project3 directory.
 
$ mix escript.build
Run the project with the command
$  ./project3 numNodes numRequests numFailuer
E.g.   $  ./project3_bonus 100 10 20
# 4. What is working

The Basic program for the Pastry algorithm is working including join and route mechanisms.
We also implemented the failuer model.

# 5. What is the largest network we can manage

For the basic program (project3.ex), up to 100,00 nodes can be supported.

Larger network may be supported, but may take a longer time.


