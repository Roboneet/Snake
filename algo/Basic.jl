# TODO: Docs
# ==============================================================
#                          Basic
# ==============================================================

# just move avoiding obstacles
struct Basic <: AbstractAlgo end

findmoves(algo, s::SType) = ntuple(x -> findmove(algo, s, x), length(s.snakes))
function findmove(algo, s::SType, i::Int; kwargs...)
	!alive(s.snakes[i]) && return (0,0)
	rand(pipe(algo, s, i; kwargs...)(DIRECTIONS))
end

pipe(algo::Type{Basic}, s::SType, i::Int) = flow(canmove(s, i)...)
basic(s::SType, i::Int) = alive(s.snakes[i]) ? (pipe(Basic, s, i)(DIRECTIONS))::DType :
	Tuple{Int,Int}[(0, 0)]

# ==============================================================
#                          SpaceChase
# ==============================================================

# Follow spacious clusters on the board
struct SpaceChase <: AbstractAlgo end

pipe(algo::Type{SpaceChase}, s::SType, i::Int) = flow(canmove(s, i)..., morespace(s, i))

spaceF = (s, i) -> reachableclusters(s, i)
function morespace(s::SType, i::Int, f=spaceF)
	c, d, r = f(s, i)
	I = head(s.snakes[i])
	return y -> begin
		Y = map(y) do x
			v = c[(x .+ I)...]
			!(v in r[i]) && return 0
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

pipe(algo::Type{FoodChase}, s::SType, i::Int) = flow(canmove(s, i)..., closestfood(s, i))

function closestfood(s::SType, i::Int)
	c = collect(s.food)
	isempty(c) && return identity
	return y -> astar(cells(s), head(s.snakes[i]), c, y)
end

# ==============================================================
#                          ComboChase
# ==============================================================

# Chase space and then food
struct ComboChase <: AbstractAlgo end

pipe(algo::Type{ComboChase}, s::SType, i::Int) = 
	flow(canmove(s, i)..., morespace(s, i), closestfood(s, i))


# ==============================================================
#                          Killer snake
# ==============================================================

# Adversarial moves
# decrease reachable space of target / kill it
struct Killer{T} <: AbstractAlgo end

pipe(algo::Type{Killer{T}}, s::SType, i::Int) where T = flow(canmove(s, i)..., stab(s, i, T))


safermove(s::SType, i::Int, t::Int) =
	safermove(s, i, t, cells(s), head(s.snakes[i]))

function safermove(s::SType, i::Int, t::Int, cls, I)
	return y -> begin
		if length(s.snakes[i]) < length(s.snakes[t])
			# dont choose a sure death move if we can't kill the target
			safe = filter(x -> !nearbigsnake(cls[(I .+ x)...],
				s.snakes[i], cls, s.snakes),
				y)
			return safe
		end
		return y
	end
end

function stab(s::SType, i::Int, t::Int)
	snakes = s.snakes
	!alive(snakes[t]) && return identity

	h, w = height(s), width(s)
	I = head(snakes[i])
	cls = cells(s)

	return y -> begin
		k = indices.(neighbours(cls[head(snakes[t])...], cls))
		K = filter(x -> (x .+ I) in k, y)
		length(snakes[i]) >= length(snakes[t]) && !isempty(K) && return K

		return safermove(s, i, t, cls, I)(y)
	end
end

# ==============================================================
#                          Dynamic Killer
# ==============================================================

const DKiller = Killer

function nearestsnake(s, i)
	snake = s.snakes[i]
	sn = filter(x -> alive(x) && id(x) != i, s.snakes)
	isempty(sn) && return i
	length(sn) == 1 && return id(sn[1])
	d = map(x -> sum(abs.(head(x) .- head(snake))), sn)
	q, j = findmin(d)
	return id(sn[j])
end

function pipe(algo::Type{Killer}, s::SType, i::Int)
	T = nearestsnake(s, i)
	pipe(Killer{T}, s, i)
end

# function findmove(algo::Type{Killer{T}}, s::SType, i::Int) where T
# 	f = flow(canmove(s, i)...,
# 		stab(s, i, T))

# 	rand(f(DIRECTIONS))
# end
