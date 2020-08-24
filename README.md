# Snake

Develop, deploy and debug snakes on [BattleSnake](https://play.battlesnake.com/).

Here's a random snake battle on terminal:
[![asciicast](https://asciinema.org/a/352451.svg)](https://asciinema.org/a/352451)

This is not a starter snake. The julia starter snake is [here](https://github.com/wookay/starter-snake-julia) 

# Usage
- `git clone https://github.com/Roboneet/Snake.git`
- `cd Snake`
- start julia
```julia
using Pkg

# activate project on current directory
Pkg.activate(".")

# this will download all the required packages for this project
# (required to be done only once)
Pkg.instantiate() 

# load environment, algorithms and some utilities
include("debug/playground.jl")
```

## Try playing

```julia

# interactive
play();

```

### Algo vs Algo

Create a match with 2 algorithms

```julia
# play a game with Grenade and PartialExplore snakes
fr = play([Grenade, PartialExplore], SnakeEnv((10, 10), 2))

# view the game, press p to play
viewgame(fr)

```

### Human vs Algo

Try playing with the an algo

```julia
fr = play([Human, PartialExplore], SnakeEnv((10, 10), 2); verbose=true)
```

## Develop algorithms 

* Create a subtype T of AbstractAlgo
* Implement `pipe` for type T to filter the best moves

### Example

```julia
struct MyAlgo <: AbstractAlgo

# Find the useful moves at state `st` for snake `i`.
# pipe returns a function which accepts a list of directions 
# and returns another list of directions
# (no mutations to the list please!)
function pipe(::Type{MyAlgo}, st, i)
	return directions -> begin
		# return the first move present
		return directions[1:1]	
	end
end

struct MyBetterAlgo <: AbstractAlgo

# combines Basic and MyAlgo using flow function
function pipe(::Type{MyBetterAlgo}, st, i)
	return dir -> begin
		# basic collision avoidance 
		# (check bounds and check if next cell is free)
		moves_in_bounds = pipe(Basic, st, i)(dir)

		# edge cases
		length(moves_in_bounds) == 0 && return dir
		length(moves_in_bounds) == 1 && return moves_in_bounds

		first_move = pipe(MyAlgo, st, i)(moves_in_bounds)

		# edge case
		length(first_move) == 0 && return moves_in_bounds

		return first_move
	end
end

fr = play([MyAlgo, MyBetterAlgo], SnakeEnv((7, 7), 2))

```

The code for creating new algorithms by combining existing algos can be made shorter using `flow` function. 

This is equivalent to the pipe function above
```julia
pipe(::Type{MyBetterAlgo}, st, i) = flow(pipe(Basic, st, i), pipe(MyAlgo, st, i))
```

## Deploy

All you need to do to setup a server that can respond to the battlesnake engine is add your snake to `algoDict` inside `app/controller.jl`

```julia
algoDict["mysnake"] = MyAlgo
```

To spin up the server locally:

```bash
julia --project="." -i app/main.jl
```

The server provides the battlesnake API at http://localhost:8080/mysnake

The port number can be changed by setting the environment variable `PORT` before starting the server.

The -i flag starts julia in interactive mode after running app/main.jl. So you can update your algorithms using the repl without a restart

To make your algorithms available on a heroku server, connect a fork of the repository to heroku and add a julia buildpack to the heroku instance

Buildpack options:

* [Optomatica/heroku-julia-sample](https://github.com/Optomatica/heroku-julia-sample)
* [wookay/heroku-buildpack-julia-13](https://github.com/wookay/heroku-buildpack-julia-13)

View heroku logs : `heroku logs --tail`

This server is written using [Mux.jl](https://github.com/JuliaWeb/Mux.jl)

## Debug

### Local Games

```julia

# create a local game
fr = play([MyAlgo, MyAlgo], SnakeEnv((7, 7), 2))

# view the game frame-by-frame
# use arrow keys to shift frames
kr = viewgame(fr)

# press q when you find the frame where things begin to go downhill
# or 
# kr = goto(fr, your_frame_number)

# get the state of the frame
st = kr.state

# get the list of moves returned by your algorithm
moves = pipe(MyAlgo, st, 1)(DIRECTIONS)

```

### BattleSnake engine games

1. Open a game on the battlesnake website. 
2. Navigate to Networks tab in DevTools
3. Filter out WebSocket requests (WS)
4. Pick a message from the messages tab
5. Copy message (right click on red arrow to get the option)

```julia
# one more utility
include("debug/socket.jl")

str = """<paste the message inside triple quotes>"""
wp = WSParser(11, 11) # for a 11x11 board

# get the game state
st = wp(str)

# view the state
Frame(st, nothing)

# get the list of moves returned by your algorithm
moves = pipe(MyAlgo, st, 1)(DIRECTIONS)

```

# Meet the inmates

This repository contains somewhat useful algorithms. Here are a few of them.

## Basic
`Basic` provides basic collision avoidance. Filters moves that doesn't collide with a wall, or a snake body.

## SpaceChase
`SpaceChase` divides the board into clusters using `reachableclusters` algo (will describe later) and moves to cells that are a part of the biggest cluster nearby.

## FoodChase
`FoodChase` uses `A*` to find the cells closest to nearest food.

## ComboChase
`ComboChase` combines `Basic`, `SpaceChase` and `FoodChase` in that order

## Grenade
`Grenade` is my first snake! It is a greedy snake if any food is close to it. Otherwise, it chases it's tail

## TreeSearch
`TreeSearch` is a tree-search algorithm parameterised by a policy, value function and a function to guide the lookahead (referred to as torch). (The names given to these parameters don't make much sense because I ran out of sensible names! Any suggestions are welcome)

`TreeSearch{NotBad,Punk,SeqLocalSearch{2}}` works pretty well without killing my server with state explosion. It does a lookahead of depth 2. SeqLocalSearch assigns a move that Grenade would choose to the other snakes on the board, except when they are two close and have a chance at killing mine. The value function considers the length of the snake and the maximum amount of space reachable by my snake (using my super `reachableclusters` algo :P). The policy chooses the better moves based on average of the values. This snake is on BattleSnake as `spark`.

## PartialExplore
`PartialExplore` adapts `reachableclusters` algo to create an approximate value function, hence eliminating tree search ( evil laugh...)

In practise, this algo can be as good as `TreeSearch` and sometimes even better that `TreeSearch` with `SeqLocalSearch` lookahead because the approximated worst case is worser than the real worst case. (This is not always a good thing)

`PartialExplore` is on BattleSnake as `Inspector Clouseau`.

# TODO
* Write more docs...!

