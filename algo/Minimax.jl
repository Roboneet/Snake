# ==============================================================
#                          LightSpace
# ==============================================================

# Complete treesearch upto level M
struct LightSpace{T <: AbstractTorch} <: AbstractAlgo end

lightspace(N=1) = LightSpace{CandleLight{N}}
torch(l::Type{LightSpace{T}}) where T = T()

function statevalue(fr::Frame, i::Int, f=reachableclusters; cap=80)
	# @show alive(fr.state.snakes[i])
	!alive(fr.state.snakes[i]) && return 0
	# display(fr)
	c, d = f(fr.state)
	# display(c)
	# display(d)
	s = fr.state
	I = head(s.snakes[i])
	n = neighbours(I, s[:height], s[:width])
	if length(s.snakes[i].trail) != 1
		J = s.snakes[i].trail[end - 1]
		n = filter(x -> x != J, n) # not on snake
	end
	ne = nempty(c, d, I)
	U = unique(map(x -> c[x...], n))

	pempty(x) = min(floor(Int, x*100/ne), cap)

	S = maximum(map(x -> haskey(d, x) && x != c[I...] ? pempty(d[x]) : 0, U)) # not on snake body
	# @show S
	return S
end

function nempty(c::AbstractArray{T,2}, d::Dict{T,Int}, k::Tuple{Int,Int}) where T
	r, ci = size(c)
	# @show k
	# display(c)

	l = c[k...]
	# @show l
	# @show d
	r*ci - d[l]
end

function minmaxreduce(fr::Frame, i::Int, f=statevalue)
	isempty(fr.children) && return f(fr, i), []
	# display(fr)
	# display(ch)

	q = Dict{Tuple{Int,Int},Int}()
	for (k, v) in fr.children
		# @show k
		# @show k[i]
		u, v = minmaxreduce(v, i, f)
		if haskey(q, k[i])
			q[k[i]] = min(q[k[i]], u)
		else
			q[k[i]] = u
		end
	end
	# @show q
	maxpairs(q)
end

function maxpairs(q::Dict{Tuple{Int,Int},T}) where T
	Q = collect(pairs(q))
	m = maximum(map(x -> x[2], Q))
	m, filter(x -> x[2] == m, Q)
end

function spacelook(T, s::SType, i::Int, f=reachableclusters)
	b = basic(s, i)
	length(b) <= 1 && return b
	fr = lookahead(T, s, i)
	# treeview(fr)
	# min - max value
	S, q = minmaxreduce(fr, i, (x...) -> statevalue(x..., f))

	map(y -> y[1], q)
end

function pipe(algo::Type{LightSpace{M}}, s::SType, i::Int) where M
	return DIR -> begin
		K = spacelook(algo, s, i)
		f = flow(closestfood(s, i))
		m = f(K)
	end
end
