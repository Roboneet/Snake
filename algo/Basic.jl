# ==============================================================
#                          Basic
# ==============================================================

# just move avoiding obstacles
struct Basic <: AbstractAlgo end

findmoves(algo::Type{T}, s) where T <: AbstractAlgo = map(x -> findmove(algo, s, x), 1:length(s.snakes))


basic(s, i) = (flow(canmove(s, i)...))(DIRECTIONS)
function findmove(algo::Type{Basic}, s, i)
	rand(basic(s, i))
end

# ==============================================================
#                          SpaceChase
# ==============================================================

# Follow spacious clusters on the board
struct SpaceChase <: AbstractAlgo end

function findmove(algo::Type{SpaceChase}, s, i)
	f = flow(canmove(s, i)...,
		morespace(s, i))

	rand(f(DIRECTIONS))
end

function morespace(s, i, f=reachableclusters)
	c, d = f(s, i)
	I = head(s.snakes[i])
	return y -> begin
		Y = map(y) do x
			v = c[(x .+ I)...]
			d[v]
		end
		return y[Y .== maximum(Y)]
	end
end

# ==============================================================
#                          FoodChase
# ==============================================================

# Chase food
struct FoodChase <: AbstractAlgo end

function findmove(algo::Type{FoodChase}, s, i)
	f = flow(canmove(s, i)...,
		closestfood(s, i))

	rand(f(DIRECTIONS))
end

function closestfood(s, i)
	c = collect(s[:food])
	return y -> astar(cells(s), head(s.snakes[i]), c, y)
end

# ==============================================================
#                          Look-ahead
# ==============================================================

# lookahead
abstract type AbstractTorch end

struct CandleLight{N} <: AbstractTorch end

(c::CandleLight{N})(s, i, fr) where N = lookahead(c, s, i, N, fr)
(c::CandleLight)(args...) = lookahead(c, args...)

function lookahead(::Type{K}, s, i) where K <: AbstractAlgo
	fr = Frame(s, nothing)
	t = torch(K)
	t(s, i, fr)
end

# A lookahead algo. Modify lookat() to reduce search space
function lookahead(T::AbstractTorch, s, i, l, fr)
	G = Game(s)
	(l == 0 || done(G)) && return fr
	c = lookat(T, s, i)
	Threads.@threads for k=1:length(c)
		X = c[k]
		g = Game(s)
		step!(g, X)
		ns = gamestate(g)
		nr = child(fr, X, Frame(ns, [], fr))
		if !done(g)
			T(ns, i, l - 1, nr)
		end
	end
	return fr
end

function lookat(T::AbstractTorch, s, i)
	N = length(s.snakes)
	moves = map(j -> basic(s, j), 1:N)
	m = length.(moves)
	arr = [zeros(Int, length(m)) for i=1:prod(m)]
	c = allcombos(m, arr, 1)
	return [[moves[i][c[j][i]] for i=1:length(moves)] for j=1:length(c)]
end

function allcombos(m, arr, n)
	length(m) < n && return arr
	if length(m) == n
		return fillcol!(arr, n, m[n], 1)
	end
	M = m[n]
	k = prod(m[(n + 1):end])
	c = allcombos(m, arr, n + 1)
	return fillcol!(c, n, M, k)
end

function fillcol!(arr, n, M, k)
	j = 1
	while j <= length(arr)
		for i=1:M
			for l=1:k
				arr[j + (i - 1)*k + l - 1][n] = i
			end
		end
		j += M*k
	end
	return arr
end


# ==============================================================
#                          LightSpace
# ==============================================================

# Complete treesearch upto level M
struct LightSpace{T <: AbstractTorch} <: AbstractAlgo end

lightspace(N=1) = LightSpace{CandleLight{N}}
torch(l::Type{LightSpace{T}}) where T = T()

function spacescore(fr, i, f=reachableclusters)
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

	pempty(x) = floor(Int, x*100/ne)

	S = maximum(map(x -> haskey(d, x) && x != c[I...] ? pempty(d[x]) : 0, U)) # not on snake body
	return S
end

function nempty(c, d, k)
	r, ci = size(c)
	l = c[k...]
	# @show d
	r*ci - d[l]
end

function minmaxreduce(fr, i, f=spacescore)
	ch = collect(pairs(fr.children))
	isempty(ch) && return f(fr, i), Dict()
	# display(fr)
	# display(ch)

	q = Dict()
	for (k, v) in pairs(fr.children)
		# @show k
		u, v = minmaxreduce(v, i, f)
		if haskey(q, k[i])
			q[k[i]] = min(q[k[i]], u)
		else
			q[k[i]] = u
		end
	end
	maxpairs(q)
end

function maxpairs(q::Dict)
	Q = collect(pairs(q))
	m = maximum(map(x -> x[2], Q))
	m, filter(x -> x[2] == m, Q)
end

function spacelook(T, s, i, f=reachableclusters)
	b = basic(s, i)
	length(b) <= 1 && return b
	fr = lookahead(T, s, i)
	# treeview(fr)
	# min - max value
	S, q = minmaxreduce(fr, i, (x...) -> spacescore(x..., f))

	map(y -> y[1], q)
end

function findmove(algo::Type{LightSpace{M}}, s, i) where M
	K = spacelook(algo, s, i)
	f = flow(closestfood(s, i))
	m = f(K)
	rand(m)
end
