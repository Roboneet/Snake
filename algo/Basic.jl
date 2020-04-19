# ==============================================================
#                          Basic
# ==============================================================

# just move avoiding obstacles
struct Basic <: AbstractAlgo end

findmoves(algo::Type{T}, s::SType) where T <: AbstractAlgo = ntuple(x -> findmove(algo, s, x), length(s.snakes))
function findmove(algo::Type{T}, s::SType, i::Int; kwargs...) where T <: AbstractAlgo
	!alive(s.snakes[i]) && return (0,0)
	rand(pipe(algo, s, i; kwargs...)(DIRECTIONS))
end

pipe(algo::Type{Basic}, s::SType, i::Int) = flow(canmove(s, i)...)
basic(s::SType, i::Int) = alive(s.snakes[i]) ? pipe(Basic, s, i)(DIRECTIONS) :
	[(0, 0)]

# ==============================================================
#                          SpaceChase
# ==============================================================

# Follow spacious clusters on the board
struct SpaceChase <: AbstractAlgo end

pipe(algo::Type{SpaceChase}, s::SType, i::Int) = flow(canmove(s, i)..., morespace(s, i))

function morespace(s::SType, i::Int, f=reachableclusters)
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

pipe(algo::Type{FoodChase}, s::SType, i::Int) = flow(canmove(s, i)..., closestfood(s, i))

function closestfood(s::SType, i::Int)
	c = collect(s.food)
	isempty(c) && return identity
	return y -> astar(cells(s), head(s.snakes[i]), c, y)
end

# ==============================================================
#                          Killer snake
# ==============================================================

# Adversarial moves
# decrease reachable space of target / kill it
struct Killer{T} <: AbstractAlgo end

pipe(algo::Type{Killer{T}}, s::SType, i::Int) where T = flow(canmove(s, i)..., stab(s, i, T))

function stab(s::SType, i::Int, t::Int)
	snakes = s.snakes
	!alive(snakes[t]) && return identity

	h, w = height(s), width(s)
	I = head(snakes[i])
	cls = cells(s)
	c, d = floodfill(s, i)

	return y -> begin
		k = indices.(neighbours(cls[head(snakes[t])...], cls))
		K = filter(x -> (x .+ I) in k, y)
		length(snakes[i]) >= length(snakes[t]) && !isempty(K) && return K
		return y
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
