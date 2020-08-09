# Snake

This repository contains the code I use to play [BattleSnake](https://play.battlesnake.com/)

[![asciicast](https://asciinema.org/a/352451.svg)](https://asciinema.org/a/352451)

# Usage
- `git clone https://github.com/Roboneet/Snake.git`
- `cd Snake`
- start julia
```julia-repl
julia> using Pkg
julia> Pkg.activate(".")
julia> include("debug/playground.jl")
```

## Try playing

```julia-repl

# interactive
julia> play();

```

### Algo vs Algo

```julia-repl
# play a game with Grenade and PartialExplore snakes
julia> fr = play([Grenade, PartialExplore], SnakeEnv((10, 10), 2))

# view the game
julia> viewgame(fr)

# goto frame 10
julia> kr = goto(fr, 10)

# get the state
julia> st = kr.state

```

### Human vs Algo

```julia-repl
julia> fr = play([Human, PartialExplore], SnakeEnv((10, 10), 2); verbose=true)
```

## Develop algorithms 

* Create a subtype T of AbstractAlgo
* Implement `pipe` for type T

### Example
```julia
struct MyAlgo <: AbstractAlgo

# find the useful moves at state `st` for snake `i`
function pipe(::Type{MyAlgo}, st, i)
	return directions -> begin
		# return the first move present
		return directions[1:1]	
	end
end

struct MyBetterAlgo <: AbstractAlgo

# combines Basic and MyAlgo
function pipe(::Type{MyBetterAlgo}, st, i)
	# flow connects the two pipes
	return flow(pipe(Basic, st, i), pipe(MyAlgo, st, i))
end

fr = play([MyAlgo, MyBetterAlgo], SnakeEnv((7, 7), 2))

```
