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

# TODO: cleanup
include("snakefillA.jl")
include("snakefillC.jl")

function ca_run(T, st; nullhead=nothing, move=nothing)
	maxrun = st.config.width * st.config.height
	gr = createCA(T, st)
	nullhead != nothing && setnullhead!(gr, nullhead, move)
	for i=1:maxrun
		CA.step!(gr)
		isempty(gr.seeds) && break
	end
	return gr
end

function setnullhead!(gr::Grid{SnakefillC,SnakefillCGlobal}, nullhead, move)
	nexthead = nullhead .+ move
	cellid = gr.cells[nexthead...].state.id
	st = gr.cells[nullhead...].state
	gr.cells[nullhead...].state = setnullhead(st, cellid)
end

spaceF = (s, i) -> reachableclusters(s, i)
spaceFCA = (s, i) -> compile(ca_run(SnakefillC, s))
function morespace(s::SType, i::Int, f=spaceFCA)
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
#                       SomeSpaceChase
# ==============================================================

# Follow spacious clusters on the board
struct SomeSpaceChase <: AbstractAlgo end

pipe(algo::Type{SomeSpaceChase}, s::SType, i::Int) = flow(canmove(s, i)..., somespace(s, i))

function somespace(s::SType, i::Int, f=spaceFCA)
	c, d, r = f(s, i)
	I = head(s.snakes[i])
	return y -> begin
		# println(colorarray(c))
		# @show r
		Y = map(y) do x
			v = c[(x .+ I)...]
			(!(haskey(r, i)) || !(v in r[i])) && return x=>0
			x=>d[v]
		end
		# @show Y
		__betterthanavg__(Dict(Y...))[2]
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
