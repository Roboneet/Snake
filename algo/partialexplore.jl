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
	L = length(rcs)
	for i=1:L
		mat, clens, root = compile(rcs[i])
		v = abs_spacevalue(st, snakeid, mat, clens, root[snakeid])
		me = get_snake_state_by_id(rcs[i].bfs, snakeid)
		# l = me.tail_lag + 1
		f = me.food_available + 1
		if L == 2
			# dont use food_available when one move could be strictly better
			values[moves[i]] = v
		else
			values[moves[i]] = v*f 
		end
		if verbose
			@show moves[i]
			println(colorarray(mat))
			println(root)
			@show v, f
		end 
		# values[moves[i]] = min(v, me.snake.health + me.power_boost)
		# values[moves[i]] = v
	end 
	return betterthanavg(values)[2]
	# mx = maximum(x -> x[2], pairs(values))
	# return map(y -> y[1], 
				# filter(x -> x[2] >= mx, collect(pairs(values))))
end


