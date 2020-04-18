# ==============================================================
#                          Minimax
# ==============================================================

# Complete treesearch upto level M with CandleLight as torch
struct Minimax{T <: AbstractTorch} <: AbstractAlgo end

minimax(N=1) = Minimax{CandleLight{N}}
torch(l::Type{Minimax{T}}) where T = T()

function statevalue(fr::Frame, i::Int)
	h = healthvalue(fr, i)
	# h - foodvalue(fr, i)
	# + 0.1*h*foodvalue(fr, i)

	v = min(spacevalue(fr, i), h) + lengthvalue(fr, i)

	return v
end
function lengthvalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	return length(fr.state.snakes[i])
end

# comparative length value
function longervalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	S = filter(x -> id(x) != i,
		filter(alive, fr.state.snakes))
	isempty(S) && return 1
	p = maximum(x -> length(S), S)
	return lengthvalue(fr, i) > p ? 1 : 0
end

# maintain social distance
function socialdistance(fr::Frame, i::Int)
	me = fr.state.snakes[i]
	!alive(me) && return 0
	config = fr.state.config
	# consider only larger snakes
	bigS = filter(x -> length(x) >= length(me),
		filter(x -> id(x) != i,
		filter(alive, fr.state.snakes)))
	max_value = config.height + config.width # not really

	isempty(bigS) && return max_value

	dm = distancematrix(fr.state, i, true)
	# display(dm)
	# @show bigS

	d = filter( x -> x >= 0 && x < Inf,
		map(x -> dm[head(x)...], bigS))
	# @show d

	isempty(d) && return max_value

	v = minimum(d)
	# @show v
	V = max(v, 0)

	# @show V
	return V
end

function healthvalue(fr::Frame, i::Int; α=1.0)
	!alive(fr.state.snakes[i]) && return 0
	round(Int, health(fr.state.snakes[i])*α)
end
function listclusters(s::SType, i::Int)
	c, d = reachableclusters(s, i)
	l = listclusters(s, i, c, d)
	return c, d, l
end

function my_peeps(s::SType, i::Int)
	I = head(s.snakes[i])
	n = neighbours(I, height(s), width(s))

	J = s.snakes[i].trail[end - 1]
	n = filter(x -> x != J, n) # not behind snake head

	cls = cells(s)
	filter(x -> begin
		xn = filter(x -> x.ishead,
			neighbours(cls[x...], cls))
		Y = vcat(map(y -> y.snakes,
			xn)...) |> unique
		isempty(Y) && error("my_peeps: That shouldn't have happened...")
		length(Y) == 1 && return true
		Z = Y[Y .!= i] # the other snakes
		W = filter(z -> z >= s.snakes[i], s.snakes[Z])
		return isempty(W)
	end, n)
end

function listclusters(s::SType, i::Int,
	c::Array{T,2}, d::Dict{T,Int}) where T
	I = head(s.snakes[i])
	n = my_peeps(s, i)

	U = unique(map(x -> c[x...], n))
	filter(x -> x != c[I[1], I[2]], U)
end

function foodvalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	s = fr.state
	c, d, l = listclusters(s, i)
	food = s.food
	r = 0
	for i=1:length(food)
		f = food[i]
		if c[f[1], f[2]] in l
			r += 1
		end
	end
	return r
end
function spacevalue(fr::Frame, i::Int; cap=100)
	# @show alive(fr.state.snakes[i])
	!alive(fr.state.snakes[i]) && return 0
	# display(fr)
	c, d, l = listclusters(fr.state, i)

	ne = nempty(size(c), filter(alive, fr.state.snakes))
	ne == 0 && return Inf
	isempty(l) && return 0
	pempty(x) = min(floor(Int, x*100/ne), cap)

	S = maximum(map(x -> haskey(d, x) ? pempty(d[x]) : 0, l))
	# @show S
	return S
end

function nempty(z, s::Array{Snake,1})
	r, ci = z
	r*ci - sum(length.(s))
end

function minmaxreduce(fr::Frame, i::Int, f=statevalue)
	isempty(fr.children) && return f(fr, i), []
	# display(fr.children)
	# display(ch)

	q = Dict{Tuple{Int,Int},Float64}()
	for (k, v) in fr.children

		u, v = minmaxreduce(v, i, f)
		if haskey(q, k[i])
			q[k[i]] = min(q[k[i]], u + 1)
		else
			q[k[i]] = u + 1 # bonus point for being alive upto this depth
		end
	end

	maxpairs(q)
end

function maxpairs(q::Dict{Tuple{Int,Int},T}) where T
	Q = collect(pairs(q))
	m = maximum(map(x -> x[2], Q))
	m, filter(x -> x[2] == m, Q)
end

function spacelook(T, s::SType, i::Int; f=minmaxreduce)
	b = basic(s, i)
	length(b) <= 1 && return b
	fr = lookahead(T, s, i)
	# viewtree(fr, i)
	# min - max value
	S, q = f(fr, i)

	map(y -> y[1], q)
end

function pipe(algo::Type{Minimax{M}}, s::SType, i::Int) where M
	return DIR -> begin
		K = spacelook(algo, s, i)
		f = flow(closestreachablefood(s, i))
		m = f(K)
	end
end

function closestreachablefood(s::SType, i::Int, f=listclusters)
	food = collect(s.food)
	isempty(food) && return identity
	c, d, l = f(s, i)
	rf = []
	for i=1:length(food)
		fo = food[i]
		if c[fo[1], fo[2]] in l
			push!(rf, fo)
		end
	end
	return y -> astar(cells(s), head(s.snakes[i]), rf, y)
end
