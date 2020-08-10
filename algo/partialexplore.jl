# TODO: Docs
struct PartialExplore <: AbstractAlgo end

pipe(::Type{PartialExplore}, s, i) = flow(
										  canmove(s, i)..., 
										  partialexplore(s, i), 
										  closestreachablefood(s, i))

function partialexplore(st::SType, i::Int; kwargs...)
	return dirs -> begin
		# @show dirs 
		rcs = considermoves(st, i, dirs; kwargs...)
		return select(st, i,dirs, rcs; kwargs...)
	end
end

function copyrc(rc::RCState) 
	return RCState(copy(rc.board), copybfs(rc.bfs), deepcopy(rc.uf))
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
		# @show rcstate
		explore!(rcstate; kwargs...) 
		push!(rcs, rcstate)
	end
	return rcs
end

function select(st, snakeid, moves, rcs; verbose=false)
	values = Dict{Tuple{Int,Int},Int}()
	for i=1:length(rcs) 
		mat, clens, root = compile(rcs[i])
		v = spacevalue(st, snakeid, mat, clens, root[snakeid])
		me = filter(x -> id(x.snake) == snakeid, rcs[i].bfs.snake_states)[1]
		l = me.tail_lag + 1
		values[moves[i]] = v*l 
		if verbose
			@show moves[i]
			println(colorarray(mat))
			println(root)
			@show v, l
		end 
		# values[moves[i]] = min(v, me.snake.health + me.power_boost)
		# values[moves[i]] = v
	end 
	return betterthanavg(values)[2]
	# mx = maximum(x -> x[2], pairs(values))
	# return map(y -> y[1], 
				# filter(x -> x[2] >= mx, collect(pairs(values))))
end


