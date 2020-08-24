include("../algo/algo.jl")

# import .SnakePit: SnakeEnv, Nsnakes, done, step!, state

include("utils.jl")
include("Human.jl")

using Statistics
using REPL
using REPL.Terminals
using REPL.TerminalMenus
# using UnicodePlots 

DEFAULT_BOARD_SIZE = (10, 10)
DEFAULT_ENV = SnakeEnv(DEFAULT_BOARD_SIZE, 1)

function life(algo, env, progress, death_reasons, lens, lifelens)
	reset!(env)
	fr = play(algo, env)
	sn = snakes(env.game)
	foreach(sn) do x
		dr = x.death_reason
		dr == nothing && return
		if !haskey(death_reasons, dr)
			death_reasons[dr] = 0
		end 
		death_reasons[dr] += 1
		push!(lens, length(x))
	end
	push!(lifelens, length(fr))
end

function lifestats(algo, env=SnakeEnv(DEFAULT_BOARD_SIZE, length(algo)); progress=false, 
				   N = 100)
	death_reasons = Dict()
	lens = []
	lifelens = []
	for i=1:N
		if progress
			@info "Life $i"
		end

		life(algo, env, progress, death_reasons, lens, lifelens)
	end
	ml = mean(lifelens)
	mlen = mean(lens)
	println("mean life: $(ml) (~ $(std(lifelens)))")
	println("mean length: $(mlen) (~ $(std(lens)))")
	println("death reasons")
	foreach(x -> println("$(x[1]) => $(x[2])"), death_reasons)

	return ml, death_reasons
end

function match(f, algos, env, N)
	for i=1:N
		f(play(algos, env))
		reset!(env)
	end
end

winstats(algos; kwargs...) = winstats(algos, SnakeEnv(DEFAULT_BOARD_SIZE, length(algos)); kwargs...)

function winstats(algos, env; N::Int=100, progress=false)
	wins = zeros(Int, length(algos))
	match(algos, env, N) do fr
		if progress
			println("winstats: $(wins)")
		end
		kr = endof(fr)
		sn = kr.state.snakes 
		k = sn[alive.(sn)]
		if !isempty(k)
			x = id(k[1])
			wins[x] += 1
			if progress
				@show x
			end
		end
	end
	return wins
end

struct Screen
	term
end

Screen() = Screen(TTYTerminal("", stdin, stdout, stderr))

start(::Nothing) = nothing
step(::Nothing, x...) = nothing
end_(::Nothing, x...) = nothing
cursor_top(term::TTYTerminal) = cursor_top(term.out_stream)
hide_cursor(term::TTYTerminal) = print(term.out_stream, "\x1b[?25l")
show_cursor(term::TTYTerminal) = print(term.out_stream, "\x1b[?25h")
function start(sc::Screen)
	Terminals.clear(sc.term)
	REPL.TerminalMenus.enableRawMode(sc.term)
	hide_cursor(sc.term)
end

function step(sc::Screen, fr)
	cursor_top(sc.term)
	show(sc.term.out_stream, fr)
end

function end_(sc::Screen, fr)
	Terminals.clear(sc.term)
	show(sc.term.out_stream, fr)

	REPL.TerminalMenus.enableRawMode(sc.term)
	show_cursor(sc.term)
end

function play(algos::Array, size::Tuple{Int,Int}; kwargs...)
	play(algos, SnakeEnv(size, length(algos)); kwargs...)
end

function play(algos::Array, env::SnakeEnv; verbose=false)
	N = Nsnakes(env)

	sc = verbose ? Screen() : nothing
	start(sc)

	fr = Frame(state(env), nothing)
	top = fr

	while !done(env)
		step(sc, fr)
		s = state(env)
		moves = ntuple(x -> findmove(algos[x], s, x), N)
		step!(env, moves)
		s′ = state(env)
		fr = child(fr, moves, Frame(s′, fr))
	end
	end_(sc, fr)

	return top
end

perframe(f, fr) = f(fr)
mapframes(f, fr) = [perframe(f, fr), mapframes(f, next(fr))...]
mapframes(f, fr::Nothing) = []

# graph(f, fr; kwargs...) = lineplot(mapframes(f, fr); kwargs...)
# graph!(f, fr, plt; kwargs...) = lineplot!(plt, mapframes(f, fr); kwargs...)
# graphvalue(fr, v::Type{<:AbstractValue}, i=1; kwargs...) = graph(x -> statevalue(v, x, i), fr; kwargs...) 
# graphvalue!(plt, fr, v::Type{<:AbstractValue}, i=1; kwargs...) = graph!(x -> statevalue(v, x, i), fr, plt; kwargs...)

# function graphgame(fr, v::Type{<:AbstractValue}; kwargs...)
# 	N = length(fr.state.snakes)
# 	ntuple(x -> graphvalue(fr, v, x; kwargs...), N)
# end

# function graphgame!(fr, v::Type{<:AbstractValue}; kwargs...)
# 	N = length(fr.state.snakes)
# 	plt = graphvalue(fr, v, 1; name=1, kwargs...)
# 	for i=2:N
# 		graphvalue!(plt, fr, v, i; name=i)
# 	end
# 	plt
# end


function listAlgos()
	return [ Basic, Grenade, sls(2),
			FoodChase, SpaceChase ]
end

function tInput(x)
	return x[request(RadioMenu(string.(x)))]
end
function play()
	println("Choose board size")
	boardSize = tInput([ (7, 7), (11, 11), (19, 19) ])
	println("Choose the number of snakes")
	n = tInput([1, 2, 4, 8])
	s = []
	while length(s) < n
		println("Choose snake $(length(s) + 1)")
		snake = tInput(listAlgos())
		push!(s, snake)
	end
	println("Snakes: $(s)")
	println("Generating a game...")
	fr = play(s, SnakeEnv(boardSize, n))
	viewgame(fr)
	return fr
end

