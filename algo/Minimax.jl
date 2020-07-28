# ==============================================================
#                    AbstractTreeReduce
# ==============================================================

abstract type AbstractTreeReduce end

statereduce(t::Type{T}, v::Type{V}, fr::Frame, i::Int) where
	 {T <: AbstractTreeReduce, V <: AbstractValue} =
	error("Not implemented for type $T")

# ==============================================================
#                          Minimax
# ==============================================================

struct Minimax <: AbstractTreeReduce end

statereduce(::Type{Minimax}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue =
	minmaxreduce(V, fr, i)[2]

function minmaxreduce(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue

	isempty(fr.children) && return statevalue(V, fr, i), [], Dict()

	q = Dict{Tuple{Int,Int},Int}()
	for (k, v) in fr.children
		u, v, w = minmaxreduce(V, v, i)
		if haskey(q, k[i])
			q[k[i]] = min(q[k[i]], u + 1)
		else
			q[k[i]] = u + 1 # bonus point for being alive upto this depth
		end
	end

	u, v = maxpairs(q)
	return u, v, q
end

function maxpairs(q::Dict{Tuple{Int,Int},T}) where T
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
	betterthanavg(q)[2]
end

function betterthanavg(q::Dict{Tuple{Int,Int},T}) where T
	Q = collect(pairs(q))
	v = map(x -> x[2], Q)
	m = sum(v) / length(v)
	# @show m, v
	m, map(y -> y[1], filter(x -> x[2] >= m, Q))
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
torch(l::Type{T}) where T <: AbstractTorch = T()

function treesearch(::Type{TreeSearch{R,V,T}},
	s::SType, i::Int) where {R, V, T}
	b = basic(s, i)
	length(b) <= 1 && return b
	fr = lookahead(T, s, i)
	# @show fr.stats.nodes
	# viewtree(fr, i, V)
	# min - max value
	statereduce(R, V, fr, i)
end

function pipe(algo::Type{TreeSearch{R,V,T}}, s::SType, i::Int) where {R,V,T}
	return DIR -> begin
		K = treesearch(algo, s, i)
		f = flow(closestreachablefood(s, i))
		m = f(K)
	end
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
