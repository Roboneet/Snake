include("../algo/algo.jl")
include("utils.jl")
include("Human.jl")
using Statistics
using REPL
using REPL.Terminals

DEFAULT_BOARD_SIZE = (10, 10)
DEFAULT_ENV = SnakeEnv(DEFAULT_BOARD_SIZE, 1)

function play(algo::Type{T}, env=DEFAULT_ENV) where T <: AbstractAlgo
	play([algo for i=1:Nsnakes(env)], env)
end

function lifestats(algo::Type{T}, env=DEFAULT_ENV; progress=false) where T <: AbstractAlgo
	m = 0
	N = 100
	death_reasons = Dict()
	lens = []
	lifelens = []
	Threads.@threads for i=1:N
		if progress
			@info "Life $i"
		end
		fr = play(algo, env)
		sn = snakes(env.game)
		foreach(sn) do x
			dr = x.death_reason
			if !haskey(death_reasons, dr)
				death_reasons[dr] = 0
			end

			death_reasons[dr] += 1
			push!(lens, length(x))
		end
		push!(lifelens, length(fr))
	end
	ml = mean(lifelens)
	mlen = mean(lens)
	println("mean life: $(ml) (~ $(std(lifelens)))")
	println("mean length: $(mlen) (~ $(std(lens)))")
	println("death reasons")
	foreach(x -> println("$(x[1]) => $(x[2])"), death_reasons)

	return ml, death_reasons
end

winstats(algos; kwargs...) = winstats(algos, SnakeEnv(DEFAULT_BOARD_SIZE, length(algos)); kwargs...)
function winstats(algos, env; N::Int=100, progress=false)
	wins = zeros(Int, length(algos))
	for i=1:N
		if progress
			@info "Life $i "
		end
		play(algos, env)
		sn = snakes(env.game)
		k = sn[alive.(sn)]
		if !isempty(k)
			x = id(k[1])
			wins[x] += 1
			if progress
				@show x
			end
		end
		reset!(env)
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

function play(algos, env; verbose=false)
	reset!(env)
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

		# d = []
		# if length(filter(alive, s.snakes)) != length(filter(alive, s′.snakes))
		# 	ids = id.(filter(alive, s′.snakes))
		# 	d = id.(filter(x -> !(id(x) in ids), filter(alive, s.snakes)))
		# end

		# fr = child(fr, moves, Frame(s′, d, fr))
		fr = child(fr, moves, Frame(s′, fr))
	end
	end_(sc, fr)

	return top
end
