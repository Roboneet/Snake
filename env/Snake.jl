"""
    SnakePit

SnakePit module provides the constructs to create an environment
for a multi-player snake game

# Examples
```julia-repl
julia> import SnakePit: SnakeEnv, step!, done 
julia> import SnakePit: UP_DIR, DOWN_DIR, LEFT_DIR, RIGHT_DIR

# create a new environment with 2 snakes
julia> env = SnakeEnv((7, 7), 2)

# move the snakes
julia> step!(env, [RIGHT_DIR, UP_DIR])

# check if the game is over
julia> done(env)

# view environment
julia> env
```

See also: [`SnakeEnv`](@ref) 

""" 
# module SnakePit

using Crayons

const SNAKE_MAX_HEALTH = 100
const UP_DIR = (-1, 0)
const DOWN_DIR = (1, 0)
const LEFT_DIR = (0, -1)
const RIGHT_DIR = (0, 1)
const DIRECTIONS = [UP_DIR, RIGHT_DIR, DOWN_DIR, LEFT_DIR]
const SINGLE_PLAYER_MODE = :SINGLE
const MULTI_PLAYER_MODE = :MULTI

mutable struct Snake
	id::Int
	trail::Array{Tuple{Int,Int},1}        # last element is the head
	health::Int
	alive::Bool
	direction::Union{Tuple{Int,Int},Nothing}
	death_reason::Union{Symbol,Nothing}
end

struct Config
	height::Int
	width::Int
	mode::Symbol
end

struct SType
	config::Config
	food::Array{Tuple{Int,Int},1}
	snakes::Array{Snake,1}
	ns::Int64
	turn::Int64
end

mutable struct Cell
	indices::Tuple{Int,Int}
	food::Bool
	snakes # snakes (indices) occupying the cell /
	# colliding at the cell
	ishead
	istail
	value # any metadata for the display
end

mutable struct Board
	cells::AbstractArray{Cell,2}
	snakes::AbstractArray{Snake,1}
	food
end

mutable struct Game
	board::Board
	turn
	foodtime
	ns
	config::Config
end

mutable struct SnakeEnv
	game::Game
end

include("./utils.jl")

"""

    SnakeEnv(size::Tuple{Int,Int}, n::Int)

Create a Snake Environment of dimentsions `size` and with `n` snakes.
SnakeEnv wraps over game and provides (step!, done, reset!) interface

---
    SnakeEnv(st::SType)

Create a Snake Environment from a game state 

See also: [SnakePit](@ref)
""" 
SnakeEnv(size::Tuple{Int,Int}, n::Int) = SnakeEnv(Game(size, n)) 
SnakeEnv(st::SType) = SnakeEnv(Game(st))

done(env::SnakeEnv) = done(env.game)

function step!(env::SnakeEnv, moves)
	game = env.game
	step!(game, moves)
	r = map(x -> alive(x) ? 1 : 0, snakes(game))
	return state(env), r
end

function reset!(env::SnakeEnv)
	g = env.game
	st = gamestate(g)
	env.game = Game((height(st), width(st),), length(snakes(g)))
	return env
end

Config() = Config(0, 0, :DEFAULT)

SType(n::Int) = SType(Config(), [], [], 0, n)
SType() = SType(Config(), [], [], 0, 0)

function Board(state::SType)
	snakes = deepcopy.(state.snakes)
	food = copy(state.food)
	c = cells(height(state), width(state), snakes, food)
	return Board(c, snakes, food)
end

# Board(board size, number of snakes)
function Board(size, n)
	c = cells(size...)
	snakes = Array{Snake,1}(undef, n)
	@inbounds for i=1:n
		snakes[i] = Snake(i)
	end

	initial_positions(snakes, c)
	Board(c, snakes, create_food(c, n))
end

Game(size, n) = Game(Board(size, n), Config(size..., single_or_multi(n)))
function Game(b::Board, c::Config, t=1)
	Game(b, t, foodtime(t), count(alive.(b.snakes)), c)
end

function Game(state::SType)
	snakes = deepcopy.(state.snakes)
	food = copy(state.food)
	c = cells(height(state), width(state), snakes, food)
	b = Board(c, snakes, food)
	return Game(b, state.config, state.turn)
end

function step!(g::Game, moves)
	board = g.board

	move(board, moves)

	g.turn += 1
	if mode(g) == MULTI_PLAYER_MODE
		if g.turn >= g.foodtime
			a = length(filter(alive, board.snakes))
			n = ceil(Int, a/2)
			board.food = create_food(board.cells, n, board.food)
			g.foodtime = foodtime(g.turn)
		end
	else
		if isempty(board.food)
			board.food = create_food(board.cells, 1, board.food)
		end
	end

	g.ns = count(alive.(snakes(g)))

	return g
end

function move(board::Board, moves)
	snakes = board.snakes

	food = board.food
	cells = board.cells

	markends(board, snakes, false)
	for (s, m) in zip(snakes, moves)
		!alive(s) && continue
		health(s, health(s) - 1)

		s.direction = m
		move(board, s)
		if !in_bounds(head(s)..., board)
			# snake hit a wall
			kill!(board, s, :COLLIDED_WITH_A_WALL)
			continue
		end

		removetail!(board, s)

		if health(s) <= 0
			# snake died out of starvation :(
			kill!(board, s, :STARVATION)
		end

		if caneat(board, s)
			health(s, SNAKE_MAX_HEALTH)
			addtail!(board, s)
		end

	end
	board.food = removefood(board, food)

	handlecollisions(board, snakes)
	markends(board, snakes, true)
end

function handlecollisions(board::Board, S)
	cells = board.cells
	eachsnake(S) do s
		@inbounds cell = cells[head(s)...]
		if length(snakes(cell)) == 1
			H = hassnakebody(cell, s)
			!H && return
			# tried to bite itself
			kill!(board, s, :BIT_ITSELF)
		end
	end

	eachsnake(S) do s
		@inbounds cell = cells[head(s)...]
		L = filter(x -> x != id(s), snakes(cell))
		length(L) == 0 && return
		peers = filter(x -> in(id(x), L), S)
		if any(map(x -> hassnakebody(cell, x), peers))
			# tried to bite another snake
			kill!(board, s, :BIT_ANOTHER_SNAKE)
			return
		end
		if any(map(x -> s < x, peers)) # it dies
			kill!(board, s, :HEAD_COLLISION)
			return
		end
		if any(map(x -> isequal(s, x), peers)) # everyone dies
			eachsnake(peers) do x
				kill!(board, x, :HEAD_COLLISION)
			end
			kill!(board, s, :HEAD_COLLISION)
			return
		end
	end
end

function removefood(board, food)
	fc = Set(food)
	for f in unique(food)
		@inbounds cell = board.cells[f...]
		if length(snakes(cell)) != 0
			eat!(cell)
			pop!(fc, f)
		end
	end
	return collect(fc)
end

function move(b::Board, s::Snake)
	d = s.direction
	if d === nothing
		s.direction = d = UP_DIR
	end
	cells = b.cells
	p = head(s) .+ d
	if in_bounds(p..., b)
		@inbounds push!(s, cells[p...])
	else
		push!(s.trail, p)
	end
end

caneat(b::Board, snake) = @inbounds hasfood(b.cells[head(snake)...])

function kill!(board::Board, s::Snake, reason)
	!s.alive && return
	# println("Kill: $(id(s)) >> $(reason)")
	cells = board.cells
	t = s.trail
	for i=1:length(t)
		@inbounds x, y = t[i]
		!in_bounds(x, y, board)  && continue
		@inbounds cell = cells[x, y]
		c = snakes(cell)
		!(id(s) in c) && continue
		cell.snakes = c[c .!= id(s)]
	end

	s.alive = false
	s.death_reason = reason
end

# end
