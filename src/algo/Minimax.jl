# TODO : Docs
# ==============================================================
#                    AbstractTreeReduce
# ==============================================================

abstract type AbstractTreeReduce end

statereduce(t::Type{T}, v::Type{V}, fr::Frame, i::Int) where
	 {T <: AbstractTreeReduce, V <: AbstractValue} =
	error("Not implemented for type $T")

# ==============================================================
#                          BestCase
# ==============================================================

struct BestCase <: AbstractTreeReduce end

statereduce(::Type{BestCase}, ::Type{V},
			fr::Frame, i::Int) where V <: AbstractValue =
bestcase(V, fr, i)[2]

function bestcase(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue

	isempty(fr.children) && return statevalue(V, fr, i), Tuple{Int,Int}[]

	U = 0
	q = Dict{Tuple{Int,Int},Int}()
	for (k, kr) in fr.children
		u, m = bestcase(V, kr, i)
		q[k[i]] = max(get!(q, k[i], 0), u + 1)
	end

	u, v = maxpairs(q)
	return u, v
end

# ==============================================================
#                          Minimax
# ==============================================================

struct Minimax <: AbstractTreeReduce end

statereduce(::Type{Minimax}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue =
	minmaxreduce(V, fr, i)[2]

keyselect(st::SType, i::Int) = keyselect(st, i, special(st))
keyselect(st::SType, i::Int, ::Nothing) = (k -> k[i])

function keyselect(st::SType, i::Int, sq::SquadConfig)
	f = friends(sq, i)
	return k -> k[f]
end

moveselect(st::SType, i::Int) = moveselect(st, i, special(st))
moveselect(st::SType, i::Int, ::Nothing) = identity
function moveselect(st::SType, i::Int, sq::SquadConfig)
	f = friends(sq, i)
	p = f .== i
	return k -> k[p][1]
end

function minmaxreduce(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue
	f = moveselect(fr.state, i)
	m = __minmaxreduce__(V, fr, i)
	m[1], f.(m[2]), m[3]
end

function __minmaxreduce__(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue
	isempty(fr.children) && return statevalue(V, fr, i), [], Dict()

	ks = keyselect(fr.state, i)
	q = Dict{Any,Int}()
	for (k, v) in fr.children
		u, v, w = minmaxreduce(V, v, i)
		key = ks(k)
		if haskey(q, key)
			q[key] = min(q[key], u + 1)
		else
			q[key] = u + 1 # bonus point for being alive upto this depth
		end
	end

	u, v = maxpairs(q)
	return u, v, q
end

function maxpairs(q::Dict{A,T}) where {A, T}
	Q = collect(pairs(q))
	m = maximum(map(x -> x[2], Q))
	m, map(y -> y[1], filter(x -> x[2] == m, Q))
end

# ==============================================================
#                          NotBad
# ==============================================================


struct NotBad <: AbstractTreeReduce end

function statereduce(::Type{NotBad}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue
	u, v, q = minmaxreduce(V, fr, i)
	betterthanavg(fr.state, i, q)[2]
end

function betterthanavg(st::SType, i::Int, q::Dict{A,T}) where {A,T}
	b = __betterthanavg__(q)
	b[1], moveselect(st, i).(b[2])
end

function __betterthanavg__(q::Dict{A,T}) where {A,T}
	Q = collect(pairs(q))
	v = map(x -> x[2], Q)
	m = sum(v) / length(v)
	# @show m, v
	m, map(y -> y[1], filter(x -> x[2] >= m, Q))
end

# ==============================================================
#                   ScaledNotBad
# ==============================================================

struct ScaledNotBad <: AbstractTreeReduce end

function statereduce(::Type{ScaledNotBad}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue
	u, v, q = minmaxreduce(V, fr, i)
	scaledreduce(fr.state, i, q)[2]
end

function scaledreduce(st::SType, i::Int, q::Dict{A,T}) where {A,T}
	b = __scaledreduce__(q)
	b[1], moveselect(st, i).(b[2])
end

function __scaledreduce__(q::Dict{A,T}) where {A,T}
	Q = collect(pairs(q))
	v = maximum(map(x -> x[2], Q))
	# that's a random threshold
	v, map(y -> y[1], filter(x -> x[2] // v >= 85 // 100, Q))
end

# ==============================================================
#                       Tree search
# ==============================================================

struct TreeSearch{
	R <: AbstractTreeReduce,
	V <: AbstractValue,
	T <: AbstractTorch
	} <: AbstractAlgo end

minimax(N=1) = TreeSearch{Minimax,JazzCop,CandleLight{N}}

function treesearch(::Type{TreeSearch{R,V,T}},
	s::SType, i::Int) where {R, V, T}
	return dir -> begin
		fr = lookahead(T, s, i)
		statereduce(R, V, fr, i)
	end
end

function pipe(algo::Type{TreeSearch{R,V,T}}, s::SType, i::Int) where {R,V,T}
	return flow(pipe(Basic, s, i), treesearch(algo, s, i))
				# closestreachablefood(s, i)
end

function closestreachablefood(s::SType, i::Int, f=listclusters) 
	food = collect(s.food)
	isempty(food) && return identity

	return y -> begin
		c, d, l = f(s, i)
		rf = []
		for i=1:length(food)
			fo = food[i]
			if c[fo[1], fo[2]] in l
				push!(rf, fo)
			end
		end
		astar(cells(s), head(s.snakes[i]), rf, y)
	end
end
