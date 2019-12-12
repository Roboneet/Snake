include("algo.jl")

struct Frame
	no
	state
	children
    deaths
    prev
end

Frame(state, prev) = Frame(state, [], prev)
Frame(state, deaths, prev) = Frame(state[:turn], state, Dict(), deaths, prev)

function Base.show(io::IO, fr::Frame)
	println(io, fr.no)
	Base.show(io, Board(fr.state))
	println(io,  "LENGTH, HEALTH")
	println(io,  
		join(map(x -> 
			"$(id(x)): $(length(x)), $(health(x))",
			 filter(alive, fr.state[:snakes])),
			 "\n"))
end

function child(fr::Frame, moves, nf::Frame)
	fr.children[moves] = nf
	return nf
end

function play(algo::Type{T}, env) where T <: AbstractAlgo
	play([algo for i=1:Nsnakes(env)], env)
end

function play(algos, env)
	N = Nsnakes(env)

	fr = Frame(state(env), nothing)
	top = fr
	while !done(env)
		s = state(env)
		moves = map(x -> findmove(algos[x], s, x), 1:N)
		step!(env, moves)
		s′ = state(env)

		m = Set(map(x -> (id(s.snakes[x]) => moves[x]), 1:length(s.snakes)))
		d = []
		if length(filter(alive, s.snakes)) != length(filter(alive, s′.snakes))
			ids = id.(filter(alive, s′.snakes))
			d = id.(filter(x -> !(id(x) in ids), filter(alive, s.snakes)))
			@show d
		end
		
		fr = child(fr, m, Frame(s′, d, fr))
	end

	return top
end

function prev(fr::Frame)
	return fr.prev
end

branches(fr) = length(values(fr.children))
nextall(fr) = collect(values(fr.children))

function next(fr::Frame, i=1) 
	branches(fr) == 0 && return nothing
	n = nextall(fr)
	return n[i]
end

function endframes(fr::Frame)
	ex = [fr]
	list = []
	while !isempty(ex)
		r = popfirst!(ex)
		while r != nothing
			println(r.no)
			if length(r.deaths) != 0
				push!(list, r)
			end

			if branches(fr) > 1
				n = nextall(r)
				push!(ex, n...)
				r = nothing
			else
				r = next(r)
			end
		end
	end
	return list
end