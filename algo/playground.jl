include("algo.jl")

DEFAULT_ENV = SnakeEnv((10, 10), 1)

function play(algo::Type{T}, env=DEFAULT_ENV) where T <: AbstractAlgo
	play([algo for i=1:Nsnakes(env)], env)
end

function lifestats(algo::Type{T}, env=DEFAULT_ENV; progress=false) where T <: AbstractAlgo
	m = 0
	len = 0
	N = 100
	death_reasons = Dict()
	for i=1:N
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
			len += length(x)
		end
		len /= length(sn)
		m += length(fr)
	end
	ml = m/N
	mlen = len/N
	println("mean life: $(ml)")
	println("mean length: $(mlen)")
	println("death reasons")
	foreach(x -> println("$(x[1]) => $(x[2])"), death_reasons)

	return ml, death_reasons
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
		moves = map(x -> findmove(algos[x], s, x), 1:N)
		step!(env, moves)
		s′ = state(env)

		d = []
		if length(filter(alive, s.snakes)) != length(filter(alive, s′.snakes))
			ids = id.(filter(alive, s′.snakes))
			d = id.(filter(x -> !(id(x) in ids), filter(alive, s.snakes)))
		end

		fr = child(fr, moves, Frame(s′, d, fr))
	end
	if verbose
		display(fr)
	end

	return top
end