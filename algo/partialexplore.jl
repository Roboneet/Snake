# TODO: Docs

function partial_lookahead(st, i, moves=DIRECTIONS)
	rcs = considermoves(st, i, moves)
	return map(x -> moves[x]=>rcs[x], 1:length(moves))
end

# not really a tree search, its basically a few floodfills
function partial_treesearch(st::SType, i::Int, valuef, reducef, moves=DIRECTIONS; kwargs...)
	evalmoves = valuef(st, i; kwargs...) ∘ partialmove(st, i; kwargs...)
	reducef(evalmoves.(moves))
end

struct PartialExplore{V,R,Greedy} <: AbstractAlgo end

pipe(::Type{PartialExplore{V,R,G}}, s, i) where {V,R,G} = flow(
										  canmove(s, i)..., 
										  partialexplore(s, i, V, R),
										  G ? closestreachablefood(s, i) : identity
										  )

function partialexplore(st::SType, i::Int, V, R; kwargs...)
	return dir -> partial_treesearch(st, i, V, R, dir; kwargs...)
end

function partialmove(st::SType, snakeid::Int; kwargs...)
	p = Union{Tuple{Int,Int},Nothing}[nothing for i=1:length(st.snakes)]
	return move -> begin
		p[snakeid] = move
		rcstate = __reachableclusters__(cells(st), st.snakes; moves=p, hero=snakeid, kwargs...)
		return move => rcstate
	end
end

function partial_coop(st, i; verbose=false)
	return p -> begin
		m = first(p)
		rc = last(p)
		c, d, r = compile(rc)
		l = length(st.snakes)
		return m=>coop(c, d, r, l)
	end
end

function partial_punk(st, i; verbose=false)
	return p -> begin
		m = first(p)
		rc = last(p)
		mat, clens, root = compile(rc)
		v = abs_spacevalue(st, i, mat, clens, root[i])
		me = get_snake_state_by_id(rc.bfs, i)
		f = me.food_available + 1
		if verbose
			@show moves[i]
			println(colorarray(mat))
			println(root)
			@show v, f
		end
		return m=>[v, f]
	end
end

function critical_value(p)
	T = length(p) <= 2
	Dict(map(x -> T ? 
			 first(x)=>last(x)[1] : 
			 first(x)=>prod(last(x)), p))
end

function partial_best(ps)
	maxpairs(critical_value(ps))[2]
end

function partial_notbad(ps)
	betterthanavg(critical_value(ps))[2]
end

