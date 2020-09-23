# TODO: Docs

abstract type AbstractPartialValue end
struct PartialCoop <: AbstractPartialValue end
struct PartialPunk <: AbstractPartialValue end

partialvalue(::Type{T}, st::SType, i::Int; kwargs...) where T = error("Not implemented for type $T")

abstract type AbstractPartialPolicy end
struct PartialNotBad <: AbstractPartialPolicy end
struct PartialBest <: AbstractPartialPolicy end
struct PartialScaled <: AbstractPartialPolicy end

partialpolicy(::Type{T}, ps) where T = error("Not implemented for type $T")

struct PartialExplore{R<:AbstractPartialPolicy,V<:AbstractPartialValue,Greedy} <: AbstractAlgo end

pipe(::Type{PartialExplore{R,V,G}}, s, i) where {R,V,G} = flow(
										  canmove(s, i)..., 
										  partialexplore(s, i, R, V),
										  G ? closestreachablefood(s, i) : identity
										  )

# not a tree search, its basically a few floodfills
function partialexplore(st::SType, i::Int, ::Type{R}, ::Type{V}; kwargs...) where {R, V}
	evalmove = partialvalue(V, st, i; kwargs...) ∘ partialmove(st, i; kwargs...)
	return (moves::DType) -> begin
		# res = evalmove.(moves)
		res = similar(moves, Pair{eltype(DType),Array{Int64,1}})
		for i=1:length(moves)
			res[i] = evalmove(moves[i])
		end
		partialpolicy(R, res)
	end
end

function partialmove(st::SType, snakeid::Int; kwargs...)
	return (move::Tuple{Int,Int}) -> begin
		p = Union{Tuple{Int,Int},Nothing}[nothing for i=1:length(st.snakes)]
		p[snakeid] = move
		# rcstate = __reachableclusters__(cells(st), st.snakes; moves=p, hero=snakeid)
		gr = ca_run(SnakefillC, st; nullhead=head(st.snakes[snakeid]), move=move)
		return move => gr
	end
end

function partialvalue(::Type{PartialCoop}, st::SType, i::Int; verbose=false)
	return p -> begin
		m = first(p)
		rc = last(p)
		c, d, r = compile(rc)
		l = length(st.snakes)
		return m=>[coop(c, d, r, l)]
	end
end

function maxminlen(mat, clens, root, gboard, i)
	!haskey(root, i) && return 0
	mycls = root[i]
	r, c = size(gboard)
	v = 0
	for j=1:c, i=1:r
		if mat[i, j] in mycls
			if gboard[i, j] > v
				v = gboard[i, j]
			end
		end
	end
	return v
end

function food_available(rc::RCState, st::SType, i::Int)
	me = get_snake_state_by_id(rc.bfs, i)
	return me.food_available
end

function food_available(gr::Grid, st::SType, i::Int)
	food = st.food
	s = states(gr)
	count(map(f -> s[f...].visitor == i, food))
end

function partialvalue(::Type{PartialPunk}, st::SType, i::Int; verbose=false)
	return (p) -> begin
		m = first(p)
		rc = last(p)
		mat, clens, root = compile(rc)
		v = abs_spacevalue(st, i, mat, clens, haskey(root, i) ? root[i] : [])
		f = food_available(rc, st, i) + 1
		k = maxminlen(mat, clens, root, visit.(states(rc)), i)
		if verbose
			@show eng(m)
			println(colorarray(mat))
			println(root)
			@show v, f
			println("="^10)
		end
		return m=>[v, f]
	end
end

function critical_value(p)
	return Dict(map(x -> first(x)=>prod(last(x)), p))
	# T = length(p) <= 2
	# Dict(map(x -> T ? 
	# 		 first(x)=>last(x)[1] : 
	# 		 first(x)=>prod(last(x)),
	# 	p)
	# )
end

partialpolicy(::Type{PartialBest}, ps) =
	maxpairs(critical_value(ps))[2]

partialpolicy(::Type{PartialNotBad}, ps) =
	__betterthanavg__(critical_value(ps))[2]

partialpolicy(::Type{PartialScaled}, ps) =
	__scaledreduce__(critical_value(ps))[2]

struct PartialSelect <: AbstractPartialPolicy end
struct PartialScaledSelect <: AbstractPartialPolicy end

function partialpolicy(::Type{PartialSelect}, ps; f=__betterthanavg__)
	length(ps) == 0 && return []
	v = Dict(ps)
	n = length(last(ps[1]))
	list = collect(keys(v))
	for i=1:n
		# @show i, eng(list)
		t = f(Dict(map(x -> x=>v[x][i], list)))[2]
		# @show eng(t)
		length(t) == 0 && return list
		length(t) == 1 && return t
		list = t
	end
	return list
end

function partialpolicy(::Type{PartialScaledSelect}, ps)
	return partialpolicy(PartialSelect, ps; f=__scaledreduce__)
end


