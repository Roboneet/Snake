# TODO: Docs
# ==============================================================
#                          Look-ahead
# ==============================================================

# lookahead
abstract type AbstractTorch end

# basic lookahead: look at everything
struct CandleLight{N} <: AbstractTorch end

(c::CandleLight{N})(s::SType, i::Int, fr::Frame) where N = lookahead(c, s, i, N, fr)
(c::CandleLight)(args...) = lookahead(c, args...)

function lookahead(::Type{K}, s::SType, i::Int) where K <: AbstractTorch
	fr = Frame(s, nothing)
	K()(s, i, fr)
end

# A lookahead algo. Modify lookat() to reduce search space
function lookahead(T::AbstractTorch, s::SType, i::Int, l::Int, fr::Frame)
	G = Game(s)
	(l == 0 || done(G)) && return fr
	c = lookat(T, s, i)
	# Threads.@threads 
	for k=1:length(c)
		X = c[k]
		if !haschild(fr, X)
			g = Game(s)
			step!(g, X)
			ns = gamestate(g)
			nr = child(fr, X, Frame(ns, fr))
		else
			nr = child(fr, X)
			ns = nr.state
		end
		if !done(ns) && alive(ns.snakes[i])
			lookahead(T, ns, i, l - 1, nr)
			fr.stats.nodes += nr.stats.nodes
		end
	end
	return fr
end

function lookat(T::AbstractTorch, s::SType, i::Int)
	N = length(s.snakes)
	moves = map(j -> basic(s, j), 1:N)
	c = allcombos(moves)
end

function allcombos(choices::AbstractArray)
	c = allcombos(length.(choices))
	return [[choices[i][c[j][i]] for i=1:length(choices)] for j=1:length(c)]
end

function allcombos(m::AbstractArray{Int,1})
	arr = [zeros(Int, length(m)) for i=1:prod(m)]
	allcombos(m, arr, 1)
end
function allcombos(m::AbstractArray{Int,1}, arr::T, n::Int) where T <: AbstractVector{<:AbstractVector{Int}}
	length(m) < n && return arr
	if length(m) == n
		return fillcol!(arr, n, m[n], 1)
	end
	M = m[n]
	k = prod(m[(n + 1):end])
	c = allcombos(m, arr, n + 1)
	return fillcol!(c, n, M, k)
end

function fillcol!(arr::T, n::Int, M::Int, k::Int) where T <: AbstractVector{<:AbstractVector{Int}}
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

# Not used
# #                          1 Algo lookahead
# # ==============================================================

# # follow the guiding staff
# # Use as: Minimax{Staff{FoodChase,2}}
# # not useful by itself
# struct Staff{A,N} <: AbstractTorch end

# (c::Staff{A,N})(s::SType, i::Int, fr::Frame) where {A,N} = lookahead(c, s, i, N, fr)
# (c::Staff)(args...) = lookahead(c, args...)

# killer(s::SType, j::Int, i::Int) = findmove(Killer{i}, s, j)

# function lookat(T::Staff{A,N}, s::SType, i::Int) where {A,N}
# 	return [ntuple(j -> j == i ? findmove(A, s, i) : killer(s, j, i), length(s.snakes))]
# end

# # ==============================================================
# #                          One search
# # ==============================================================

# # look at all possible basic moves, with adversarial agents

# struct OneSearch <: AbstractTorch end
# (c::OneSearch)(s::SType, i::Int, fr::Frame) = lookahead(c, s, i, 1, fr)
# (c::OneSearch)(args...) = lookahead(c, args...)

# function killermoves(s::SType, i::Int, m)
# 	N = length(s.snakes)
# 	l = Dict(ntuple(
# 		j -> j == i ?
# 			j=>m :
# 			j=>killer(s, j, i),
# 		N)...)
# 	moves = map(x -> ntuple(j -> j == i ? x : l[j], N), l[i])
# end

# function lookat(T::OneSearch, s::SType, i::Int)
# 	killermoves(s, i, basic(s, i))
# end

# ==============================================================
#                          Seq search
# ==============================================================

# look at all possible basic moves, with sequential adversarial agents

struct SeqSearch <: AbstractTorch end
(c::SeqSearch)(s::SType, i::Int, fr::Frame) = lookahead(c, s, i, 1, fr)
(c::SeqSearch)(args...) = lookahead(c, args...)

struct SeqKiller{T,M} <: AbstractAlgo end
pipe(algo::Type{SeqKiller{T,M}}, s::SType, i::Int) where {T,M} =
	flow(pipe(Basic, s, i), seqkiller(s, i, T, M)...)

# wiser killer, because it knows what the target is going to do
function seqkiller(s, j, i, x)
	!alive(s.snakes[j]) && return (identity,)
	h = head(s.snakes[i]) .+ x
	k = length(s.snakes[j]) >= length(s.snakes[i])

	return k ? (choose(ele -> begin
		# choose a surely killer move
		(head(s.snakes[j]) .+ ele) == h
	end),)  : (safermove(s, j, i),)
end

function seqkillermoves(s::SType, i::Int, m)
	N = length(s.snakes)
	moves = map(x -> ntuple(j -> j == i ? x :
		findmove(SeqKiller{i,x}, s, j), N), m)
end

function lookat(T::SeqSearch, s::SType, i::Int)
	seqkillermoves(s, i, basic(s, i))
end


# ==============================================================
#                          Seq local search
# ==============================================================

# look at all possible basic moves, with sequential adversarial agents

struct SeqLocalSearch{N} <: AbstractTorch end
(c::SeqLocalSearch{N})(s::SType, i::Int, fr::Frame) where N = lookahead(c, s, i, N, fr)
(c::SeqLocalSearch{N})(args...) where N = lookahead(c, args...)

sls(N=4) = TreeSearch{Minimax,JazzCop,SeqLocalSearch{N}}

function within(s, i, r)
	snakes = Set(Snake[])
	total = Set(s)
	# @show i
	for k=1:length(i)
		# @show k, length(i)
		n = filter(x -> begin
				for j=1:length(x.trail)
					all(abs.((x.trail[j] .- i[k])) .<= r) &&
					 return true
				end
				return false
			end,
			collect(total))
		for x in n
			pop!(total, x)
		end
		snakes = union(snakes, n)
		isempty(total) && break
	end
	return collect(snakes)
end

# r = list of neighbours
# x = specific move of our snake
function seqlocalmoves(s::SType, i::Int, x, r)
	# try all deadly moves
	N = length(s.snakes)
	as = id.(r)
	aps = map(a -> a=>pipe(SeqKiller{i,x}, s, a), as)
	ns = Dict(map(ap -> ap[1]=>(ap[2](DIRECTIONS)), aps))
	l = map(j -> j == i ?
			[x] :
			j in as ?
			ns[j] :
			[findmove(Grenade, s, j)],
		1:N)
	return allcombos(l)
end

function seqlocalmoves(s::SType, i::Int, m)
	# search all moves when a snake is nearby
	# to avoid any false hopes
	N = length(s.snakes)
	cls = cells(s)

	S = filter(alive, s.snakes)
	moves = []
	S = filter(x -> id(x) != i, S)
	if length(S) == 1
		for i2=1:length(m)
			x = m[i2]
			push!(moves, seqlocalmoves(s, i, x, S)...)
		end
		return moves
	end
	R = within(S, s.snakes[i].trail, 2)


	for i2=1:length(m)
		x = m[i2]
		h = head(s.snakes[i]) .+ x
		# r = within(R, [h], 1)
		r = R
		# @show head.(r), h
		if length(r) > 1 || isempty(r)
			# too many local snakes
			# fallback to seq search
			# or empty
			nt = ntuple(j -> j == i ? x :
				findmove(SeqKiller{i,x}, s, j), N)
			# @show nt
			push!(moves, nt)
		else
			push!(moves, seqlocalmoves(s, i, x, r)...)
		end
	end
	# @show moves
	return moves
end

function lookat(T::SeqLocalSearch{N}, s::SType, i::Int) where N
	seqlocalmoves(s, i, basic(s, i))
end

# Not used
# # ==============================================================
# #                          Intersecting Algo lookahead
# # ==============================================================

# # Explore Intersecting moves from different algos
# struct Intersect{A <: Tuple,N} <: AbstractTorch end
# function (c::Intersect{A,N})(s::SType, i::Int, fr::Frame) where {A,N}
# 	lookahead(c, s, i, N, fr)
# end
# (c::Intersect{A,N})(args...) where {A,N} = lookahead(c, args...)

# function lookat(::Intersect{A,N}, s::SType, i::Int) where A <: Tuple where N
# 	d = DIRECTIONS
# 	for x in A.parameters
# 		p = pipe(x, s, i)
# 		k = intersect(d, p(DIRECTIONS))
# 		if isempty(k)
# 			break
# 		else
# 			d = k
# 		end
# 	end
# 	# @show d
# 	# display(Board(s))
# 	# @show statevalue(Frame(s, nothing), i)

# 	seqlocalmoves(s, i, d)
# end

# # Base.intersect(x::Type{<:AbstractAlgo}...) = intersect(x, 2)
# # Base.intersect(x, N::Int) = Minimax{Intersect{Tuple{x...},N}}

# # ==============================================================
# #                         Explorer 
# # ==============================================================
# # (my Dora) 
# # lookahead based on partial explore

# struct Explorer <: AbstractTorch end

# (c::Explorer)(s::SType, i::Int, fr::Frame) = lookahead(c, s, i, 1, fr)
# (c::Explorer)(args...) = lookahead(c, args...)

# function lookat(::Explorer, s::SType, i::Int)
# 	dir = basic(s, i)
# 	N = length(s.snakes)
# 	l = map(j -> j == i ?
# 			dir :
# 			[findmove(PartialExplore, s, j)],
# 		1:N)
# 	return allcombos(l)
# end

