include("../env/Snake.jl")
include("../utils/frames.jl")

include("utils.jl")
include("Human.jl")

using Statistics
using REPL
using REPL.Terminals
using UnicodePlots

DEFAULT_BOARD_SIZE = (10, 10)
DEFAULT_ENV = SnakeEnv(DEFAULT_BOARD_SIZE, 1)

function play(algo, env=DEFAULT_ENV)
	play([algo for i=1:Nsnakes(env)], env)
end

function lifestats(algo, env=DEFAULT_ENV; progress=false)
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
			println("winstats: $(wins)")
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

function play(algos::Array, size::Tuple{Int,Int}; kwargs...)
	play(algos, SnakeEnv(size, length(algos)); kwargs...)
end

function play(algos::Array, env::SnakeEnv; verbose=false)
	# reset!(env)
	N = Nsnakes(env)

	sc = verbose ? Screen() : nothing
	start(sc)

	fr = Frame(state(env), nothing)
	top = fr

	times = [Float32[] for i=1:N]
	while !done(env)
		step(sc, fr)
		s = state(env)
		# moves = ntuple(x -> findmove(algos[x], s, x), N)
		moves = []
		for x=1:N
			a = algos[x]
			t = @elapsed v = findmove(a, s, x)
			push!(times[x], t)
			push!(moves, v)
	    end
		step!(env, moves)
		s′ = state(env)
		fr = child(fr, moves, Frame(s′, fr))
	end
	end_(sc, fr)

	return top, times
end

perframe(f, fr) = f(fr)
mapframes(f, fr) = [perframe(f, fr), mapframes(f, next(fr))...]
mapframes(f, fr::Nothing) = []

graph(f, fr; kwargs...) = lineplot(mapframes(f, fr); kwargs...)
graph!(f, fr, plt; kwargs...) = lineplot!(plt, mapframes(f, fr); kwargs...)
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

