# TODO: Docs

function partial_lookahead(st, i, moves=DIRECTIONS)
	rcs = considermoves(st, i, moves)
	return map(x -> moves[x]=>rcs[x], 1:length(moves))
end
# not really a tree search, its basically a few floodfills
function partial_treesearch(st::SType, i::Int, vf, rf, moves=DIRECTIONS)
	pl = partial_lookahead(st, i, moves)
	return rf(map(x -> vf(st, i, x), pl))
end

struct PartialExplore{V,R,Greedy} <: AbstractAlgo end

pipe(::Type{PartialExplore{V,R,G}}, s, i) where {V,R,G} = flow(
										  canmove(s, i)..., 
										  partialexplore(s, i, V, R),
										  G ? closestreachablefood(s, i) : identity
										  )

function partialexplore(st::SType, i::Int, V, R; kwargs...)
	return dir -> partial_treesearch(st, i, V, R, dir)
end

function considermoves(st::SType, snakeid::Int, moves::Array{Tuple{Int,Int},1}; kwargs...)
	rcs = RCState[] 
	p = Union{Tuple{Int,Int},Nothing}[nothing for i=1:length(st.snakes)]
	for i=1:length(moves)
		m = moves[i]
		p[snakeid] = m
		# @show p
		rcstate = create(cells(st), st.snakes; moves=p, hero=snakeid) 
		markheads(rcstate)
		explore!(rcstate; kwargs...) 
		push!(rcs, rcstate)
	end
	return rcs
end

function partial_coop(st, i, p; verbose=false)
	m = first(p)
	rc = last(p)
	c, d, r = compile(rc)
	l = length(st.snakes)
	return m=>coop(c, d, r, l)
end

function partial_punk(st, i, p; verbose=false)
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

