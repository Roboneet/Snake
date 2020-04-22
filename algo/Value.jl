# ==================================================================
#                         Interface
# ==================================================================

abstract type AbstractValue end

# for external use
function statevalue(::Type{T}, fr::Frame, i::Int) where T <: AbstractValue
    value(T, fr, i)
end

# implementaion specific
function value(::Type{T}, fr::Frame, i::Int) where T <: AbstractValue
    println("Not implemented for type $T")
end

# ==================================================================
#                         LengthValue
# ==================================================================
struct LengthValue <: AbstractValue end

value(::Type{LengthValue}, fr::Frame, i::Int) = lengthvalue(fr, i)

function lengthvalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	return length(fr.state.snakes[i])
end

# ==================================================================
#                         LongerValue
# ==================================================================

struct LongerValue <: AbstractValue end

value(::Type{LongerValue}, fr::Frame, i::Int) = longervalue(fr, i)

# comparative length value
function longervalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0
	S = filter(x -> id(x) != i,
		filter(alive, fr.state.snakes))
	isempty(S) && return 1
	p = maximum(x -> length(S), S)
	return lengthvalue(fr, i) > p ? 1 : 0
end

# ==================================================================
#                         SocialDistance
# ==================================================================

struct SocialDistance <: AbstractValue end

value(::Type{SocialDistance}, fr::Frame, i::Int) = socialdistance(fr, i)

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

# ==================================================================
#                         HealthValue
# ==================================================================

struct HealthValue <: AbstractValue end

value(::Type{HealthValue}, fr::Frame, i::Int) = healthvalue(fr, i)

function healthvalue(fr::Frame, i::Int; α=1.0)
	!alive(fr.state.snakes[i]) && return 0
	round(Int, health(fr.state.snakes[i])*α)
end

# ==================================================================
#                         SpaceValue
# ==================================================================

struct SpaceValue{N} <: AbstractValue end

value(::Type{SpaceValue}, fr::Frame, i::Int) = spacevalue(fr, i)
value(::Type{SpaceValue{N}}, fr::Frame, i::Int) where N =
	spacevalue(fr, i; cap=N)

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

function nempty(z, s::Array{Snake,1})
	r, ci = z
	r*ci - sum(length.(s))
end

# ==================================================================
#                         FoodValue
# ==================================================================

struct FoodValue <: AbstractValue end

value(::Type{FoodValue}, fr::Frame, i::Int) = foodvalue(fr, i)

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

# ==================================================================
#                         JazzCop
# ==================================================================

struct JazzCop <: AbstractValue end

function value(::Type{JazzCop}, fr::Frame, i::Int)
	h = value(HealthValue, fr, i)
	s = value(SpaceValue, fr, i)
	l = value(LengthValue, fr, i)

	return min(h, s) + l
end

# ==================================================================
#                         HipHop
# ==================================================================

struct HipHop <: AbstractValue end

function value(::Type{HipHop}, fr::Frame, i::Int)
	h = value(HealthValue, fr, i)
	s = value(SpaceValue, fr, i)

	return min(h, s)
end

# ==================================================================
#                         ThreatValue
# ==================================================================

struct ThreatValue <: AbstractValue end

value(::Type{ThreatValue}, fr::Frame, i::Int) = threatvalue(fr, i)

# wip
function threatvalue(fr::Frame, i::Int)
	!alive(fr.state.snakes[i]) && return 0

	c, d, l = listclusters(fr.state, i)
	println(colorarray(c))
	return 0
end
