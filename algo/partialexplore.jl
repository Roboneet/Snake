# TODO: Docs

abstract type AbstractPartialValue end
struct PartialCoop <: AbstractPartialValue end
struct PartialPunk <: AbstractPartialValue end

partialvalue(::Type{T}, st::SType, i::Int; kwargs...) where T = error("Not implemented for type $T")

abstract type AbstractPartialPolicy end
struct PartialNotBad <: AbstractPartialPolicy end
struct PartialBest <: AbstractPartialPolicy end

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
		rcstate = __reachableclusters__(cells(st), st.snakes; moves=p, hero=snakeid, kwargs...)
		return move => rcstate
	end
end

function partialvalue(::Type{PartialCoop}, st::SType, i::Int; verbose=false)
	return p -> begin
		m = first(p)
		rc = last(p)
		c, d, r = compile(rc)
		l = length(st.snakes)
		return m=>coop(c, d, r, l)
	end
end

function partialvalue(::Type{PartialPunk}, st::SType, i::Int; verbose=false)
	return (p::Pair{Tuple{Int,Int},RCState}) -> begin
		m = first(p)
		rc = last(p)
		mat, clens, root = compile(rc)
		v = abs_spacevalue(st, i, mat, clens, root[i])
		me = get_snake_state_by_id(rc.bfs, i)
		f = me.food_available + 1
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
	T = length(p) <= 2
	Dict(map(x -> T ? 
			 first(x)=>last(x)[1] : 
			 first(x)=>prod(last(x)), 
		p)
	)
end

function partialpolicy(::Type{PartialBest}, ps)
	maxpairs(critical_value(ps))[2]
end

function partialpolicy(::Type{PartialNotBad}, ps)
	betterthanavg(critical_value(ps))[2]
end

