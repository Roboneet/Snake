"""
    SnakePit

SnakePit provides the constructs to create an environment
for a multi-player snake game

# Examples
```julia-repl
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
const DType = typeof(DIRECTIONS) 
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
	special # anything special about the game goes here 
end

struct SType
	config::Config
	food::Array{Tuple{Int,Int},1}
	snakes::Array{Snake,1}
	ns::Int64
	turn::Int64
	hazards::Array{Tuple{Int,Int},1}
end

mutable struct Cell
	indices::Tuple{Int,Int}
	food::Bool
	snakes::Array{Int,1} # snakes (indices) occupying the cell /
	# colliding at the cell
	ishead::Bool
	istail::Bool
	hazardous::Bool
end

mutable struct Board
	cells::AbstractArray{Cell,2}
	snakes::AbstractArray{Snake,1}
	food
	hazards
end

mutable struct Game
	board::Board
	turn
	foodtime
	ns
	config::Config
end

abstract type AbstractEnv end
mutable struct SnakeEnv <: AbstractEnv
	game::Game
end

const HAZARDS = Tuple{Int,Int}[]
Config() = Config(0, 0, SINGLE_PLAYER_MODE, nothing)
SType() = SType(Config(), Tuple{Int,Int}[], Snake[], 0, 0, HAZARDS)

include("./utils.jl")
include("./Squad.jl")

# if there are special rules, modify this
function rules(::Nothing)
	# each function is applied on all of the snakes, before the next
	return [
			kill_if_collided_with_wall, 
			decrease_health_by_one,
			decrease_health_in_hazard_zone,
			kill_if_starved,
			eat_if_possible,
			kill_if_bit_itself,
			kill_if_bit_another_snake,
			kill_if_head_collision
			]
end

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

game(env::SnakeEnv) = env.game
done(env::AbstractEnv) = done(game(env))

function step!(env::AbstractEnv, moves)
	g = game(env)
	step!(g, moves)
	return state(env), 0
end

game!(env::SnakeEnv, g) = (env.game = g;)
state2newgame(st::SType, ::Type{Game}) = Game((height(st), width(st),), length(snakes(st));
										   hazards=st.hazards,
										   special=special(st))

function reset!(env::AbstractEnv)
	g = game(env)
	st = gamestate(g)
	game!(env, state2newgame(st, Game))
	return env
end

function Board(state::SType)
	snakes = deepcopy.(state.snakes)
	food = copy(state.food)
	c = cells(height(state), width(state), snakes, food, state.hazards)
	return Board(c, snakes, food, state.hazards)
end

# Board(board size, number of snakes)
function Board(size, n, hazards=Tuple{Int,Int}[])
	c = cells(size...)
	snakes = Array{Snake,1}(undef, n)
	@inbounds for i=1:n
		snakes[i] = Snake(i)
	end

	initial_positions(snakes, c)
	mark_hazards(c, hazards)
	Board(c, snakes, create_food(c, n), hazards)
end

Game(size::Tuple{Int,Int}, n::Int; hazards::Array{Tuple{Int,Int},1}=HAZARDS, special=nothing) = 
Game(Board(size, n, hazards), Config(size..., single_or_multi(n), special))

function Game(b::Board, c::Config, t::Int=1)
	Game(b, t, foodtime(t), count(alive.(b.snakes)), c)
end

function Game(state::SType)
	b = Board(state)
	return Game(b, state.config, state.turn)
end

function SnakeEnv(size::Tuple{Int,Int}, n::Int, lims::Tuple{Int,Int,Int,Int})
	r, c = size
	i1, i2, j1, j2 = lims
	hazards = Tuple{Int,Int}[]
	for i=1:r, j=1:c
		i1 < i < i2 && j1 < j < j2 && continue
		push!(hazards, (i, j))
	end
	b = Board(size, n, hazards)
	return SnakeEnv(Game(b, Config(size..., single_or_multi(n), nothing)))
end

function step!(g::Game, moves)
	board = g.board

	g.turn += 1
	move(board, moves, rules(special(g)))
	spawn_food(g)

	g.ns = count(alive.(snakes(g)))
	return g
end

function in_hazard_zone(cells, h)
	return cells[h...].hazardous
end

function resolvemoves(board::Board, snakes::Array{Snake,1}, rules)
	for r in rules
		length(snakes) == 0 && return
		snakes = __eachsnake__(s -> r(board, s), snakes)
	end
end

function move(board::Board, moves, rules)
	snakes = board.snakes
	food = board.food
	markends(board, snakes, false)

	eachsnake(snakes) do s
		s.direction = moves[id(s)]
		move(board, s)
	end

	resolvemoves(board, snakes, rules)

	markends(board, snakes, true)
	board.food = removefood(board, food)
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
	removetail!(b, s)
end

caneat(b::Board, snake) = @inbounds hasfood(b.cells[head(snake)...])

function kill!(board::Board, s::Snake, reason)
	!s.alive && return
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
