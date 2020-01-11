# ==============================================================
#                          LightSpace
# ==============================================================

# Complete treesearch upto level M with CandleLight as torch
struct LightSpace{T <: AbstractTorch} <: AbstractAlgo end

lightspace(N=1) = LightSpace{CandleLight{N}}
torch(l::Type{LightSpace{T}}) where T = T()

function statevalue(fr::Frame, i::Int)
	h = healthvalue(fr, i)
	# h - foodvalue(fr, i)
	min(spacevalue(fr, i), h) + 0.1*h*foodvalue(fr, i)
end
function lengthvalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	return length(fr.state.snakes[i])
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
function listclusters(s::SType, i::Int,
	c::Array{T,2}, d::Dict{T,Int}) where T
	I = head(s.snakes[i])
	n = neighbours(I, s[:height], s[:width])
	if length(s.snakes[i].trail) != 1
		J = s.snakes[i].trail[end - 1]
		n = filter(x -> x != J, n) # not on snake
	end
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
	# display(c)
	# display(d)
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
		# @show k
		# @show k[i]
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
	# treeview(fr)
	# min - max value
	S, q = f(fr, i)

	map(y -> y[1], q)
end

function pipe(algo::Type{LightSpace{M}}, s::SType, i::Int) where M
	return DIR -> begin
		K = spacelook(algo, s, i)
		f = flow(closestfood(s, i))
		m = f(K)
	end
end
