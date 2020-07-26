struct PartialExplore <: AbstractAlgo end

pipe(::Type{PartialExplore}, s, i) = flow(
										  canmove(s, i)..., 
										  partialexplore(s, i), 
										  closestreachablefood(s, i))

function partialexplore(st::SType, i::Int) 
	return dirs -> begin
		rcs = partialexplore(create(cells(st), st.snakes), i, dirs)
		return select(st, i,dirs, rcs)
	end
end

function copyrc(rc::RCState) 
	return RCState(copy(rc.board), copybfs(rc.bfs), deepcopy(rc.uf))
end

function copybfs(bfs::SnakeBFS)
	return SnakeBFS(deepcopy(bfs.cells),
				   copyss.(bfs.snake_states),
				   bfs.generation)
end

function copyss(ss::SnakeState)
	return SnakeState(ss.snake, deepcopy(ss.exploration_set), ss.has_eaten,
					  ss.tail_lag, ss.power_boost)

end

function partialexplore(rc::RCState, snakeid::Int, moves::Array{Tuple{Int,Int},1})
	for i=1:length(rc.bfs.snake_states)
		ss = rc.bfs.snake_states[i]
		ss.snake.id == snakeid && continue
		markhead(rc, ss, head(ss.snake))
	end

	mysnake = filter(x -> id(x.snake) == snakeid, rc.bfs.snake_states)[1].snake
	explore_once!(rc.board, rc.bfs, rc.uf)
	rcs = map(x -> copyrc(rc), moves)

	h = head(mysnake)
	# push!(mysnake.trail, (0, 0))

	for i=1:length(moves)
		m = moves[i]
		rc_ = rcs[i]

		mysnakestate = filter(x -> id(x.snake) == snakeid, rc_.bfs.snake_states)[1]
		c = h .+ m
		markhead(rc_, mysnakestate, c)
		# mysnake.trail[end] = c
		
		explore!(rc_)
	end
	# pop!(mysnake.trail)
	return rcs
end

function select(st, snakeid, moves, rcs)
	values = Dict{Tuple{Int,Int},Int}()
	for i=1:length(rcs) 
		mat, clens, root = compile(rcs[i])
		# @show moves[i]
		# println(colorarray(mat))
		# println(root)
		v = spacevalue(st, snakeid, mat, clens, root[snakeid])
		me = filter(x -> id(x.snake) == snakeid, rcs[i].bfs.snake_states)[1]
		l = me.tail_lag + 1
		values[moves[i]] = v*l 
		# values[moves[i]] = v
	end 
	return betterthanavg(values)[2]
end


