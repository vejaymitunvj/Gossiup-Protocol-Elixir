# Random Gossip protocol implementation for spreading rumor/message across a network or calculate aggregate sum in a networked distributed system written in Elixir

### Group Members:         
  * Muthu Kumaran Manoharan   (UFID# 9718-4490)
  * Vejay Mitun Venkatachalam Jayagopal (UFID# 3106-5997)

### Steps to run code:
  * Create a new mix project using command “mix new project2”
  * Extract zip file file containing proj2.ex, main.exs and mix.exs files.
  * Copy main.exs and mix.exs to the project folder created.(Replace the default mix.exs file created with ours)
  * Delete the default project2.ex created in the lib folder and copy our proj2.ex to the lib folder.
  *	Open cmd or terminal , run project by issuing commands “mix compile” and  “mix run –-no-halt main.exs <node #> <topology> <algorithm>” for the project to run continuously and terminate it when the results are received.
    * eg #1: mix run --no-halt main.exs 1000 randhoneycomb gossip
	* eg #2: mix run --no-halt main.exs 1000 3Dtorus push-sum
	
### Topology supported and largest network tested:

#### Topology type:						argument:						Largest # of nodes tested:
	 --------------                     ---------						--------------------------
  * full network 				-		full				-				10000
  * line network 				-		line				-				50000
  * 2D Random grid network		-		rand2D				-				20000
  * Honeycomb network			-		honeycomb			-				10000
  * Random Honeycomb network	-		randhoneycomb		-				10000
  * 3D Torus network 			-		3Dtorus				-				20000
  
