include("../algo/algo.jl")
include("utils.jl")
using Statistics

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
		play(algos, env)
		sn = snakes(env.game)
		k = sn[alive.(sn)]
		if !isempty(k)
			x = id(k[1])
			wins[x] += 1
		end
		reset!(env)
		if progress
			@info "Life $i "
		end
	end
	return wins
end

function play(algos, env; verbose=false)
	reset!(env)
	N = Nsnakes(env)

	fr = Frame(state(env), nothing)
	top = fr
	while !done(env)
		if verbose
			display(fr)
		end
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
	if verbose
		display(fr)
	end

	return top
end
