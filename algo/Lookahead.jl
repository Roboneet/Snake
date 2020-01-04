# ==============================================================
#                          Look-ahead
# ==============================================================

# lookahead
abstract type AbstractTorch end

# basic lookahead: look at everything
struct CandleLight{N} <: AbstractTorch end

(c::CandleLight{N})(s::SType, i::Int, fr::Frame) where N = lookahead(c, s, i, N, fr)
(c::CandleLight)(args...) = lookahead(c, args...)

function lookahead(::Type{K}, s::SType, i::Int) where K <: AbstractAlgo
	fr = Frame(s, nothing)
	t = torch(K)
	t(s, i, fr)
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
			T(ns, i, l - 1, nr)
		end
	end
	return fr
end

function lookat(T::AbstractTorch, s::SType, i::Int)
	N = length(s.snakes)
	moves = map(j -> basic(s, j), 1:N)
	m = length.(moves)
	arr = [zeros(Int, length(m)) for i=1:prod(m)]
	c = allcombos(m, arr, 1)
	return [[moves[i][c[j][i]] for i=1:length(moves)] for j=1:length(c)]
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

# ==============================================================
#                          1 Algo lookahead
# ==============================================================

# follow the guiding staff
# Use as: LightSpace{Staff{FoodChase,2}}
# not useful by itself
struct Staff{A,N} <: AbstractTorch end

(c::Staff{A,N})(s::SType, i::Int, fr::Frame) where {A,N} = lookahead(c, s, i, N, fr)
(c::Staff)(args...) = lookahead(c, args...)

killer(s::SType, j::Int, i::Int) = findmove(Killer{i}, s, j)

function lookat(T::Staff{A,N}, s::SType, i::Int) where {A,N}
	return [ntuple(j -> j == i ? findmove(A, s, i) : killer(s, j, i), length(s.snakes))]
end

# ==============================================================
#                          One search
# ==============================================================

# look at all possible basic moves, with adversarial agents

struct OneSearch <: AbstractTorch end
(c::OneSearch)(s::SType, i::Int, fr::Frame) = lookahead(c, s, i, 1, fr)
(c::OneSearch)(args...) = lookahead(c, args...)

function lookat(T::OneSearch, s::SType, i::Int)
	N = length(s.snakes)
	l = Dict(ntuple(
		j -> j == i ?
			j=>basic(s, i) :
			j=>killer(s, j, i),
		N)...)
	moves = map(x -> ntuple(j -> j == i ? x : l[j], N), l[i])
end

# ==============================================================
#                          N Algo lookahead
# ==============================================================

# follow all the guiding staffs
# Use as: LightSpace{NStaff{Tuple{Staff{FoodChase,2},Staff{SpaceChase,2}}}}
# not useful by itself
struct NStaff{A <: Tuple} <: AbstractTorch end

function (c::NStaff{A})(s::SType, i::Int, fr::Frame) where A <: Tuple
	o = OneSearch()
	o(s, i, fr)
	for x in A.parameters
		t = x()
		t(s, i, fr)
	end
	return fr
end

# ==============================================================
#                          Intersecting Algo lookahead
# ==============================================================

# follow all the guiding staffs
# Use as: LightSpace{NStaff{Tuple{Staff{FoodChase,2},Staff{SpaceChase,2}}}}
# not useful by itself
struct Intersect{A <: Tuple,N} <: AbstractTorch end
function (c::Intersect{A,N})(s::SType, i::Int, fr::Frame) where {A,N}
	o = OneSearch()
	o(s, i, fr)
	lookahead(c, s, i, N, fr)
end
(c::Intersect{A,N})(args...) where {A,N} = lookahead(c, args...)

function lookat(::Intersect{A,N}, s::SType, i::Int) where A <: Tuple where N
	d = DIRECTIONS
	for x in A.parameters
		p = pipe(x, s, i)
		k = intersect(d, p(DIRECTIONS))
		if isempty(k)
			break
		else
			d = k
		end
	end

	M = length(s.snakes)
	l = Dict(ntuple(
		j -> j == i ?
			j=>d :
			j=>killer(s, j, i),
		M)...)
	moves = map(x -> ntuple(j -> j == i ? x : l[j], M), d)
end

Base.intersect(x::Type{<:AbstractAlgo}...) = intersect(x, 2)
Base.intersect(x, N::Int) = LightSpace{Intersect{Tuple{x...},N}}
