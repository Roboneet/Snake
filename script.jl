include("Snake.jl")

function play(N::Int = 4)
	env = SnakeEnv((8, 8), N)
	
	display(env)

	memory = (moves=[], states=[])
	# try 
		while !done(env)
			s = state(env)
			
			moves = findmoves(s, N)
			push!(memory[:states], s)
			push!(memory[:moves], moves)
			
			step!(env, moves)
			@show state(env)[:turn]
			display(env)
		end
		push!(memory[:states], state(env))
	# catch e
	# 	show(e)
	# end

	return memory
end


function findmoves(s, N)
	# return map(x -> find_move(s, x), 1:N)
	return assign(s, N)
end

function findmove(s, i)
	# one problem: it will never moveto the cell that contained another snake's tail in the previous trun
	good_moves = astar(s, i)
	# @show good_moves
	return rand(good_moves)
end

# prefer moves that could eliminate competition
# avoid ones that could eliminate the snake
# function snake_eye(state, moves, i) 
# 	snakes = state[:snakes]
# 	snake = snakes[i]
# 	v = map(x -> sum(map(y -> begin
# 			!y.alive && return 0
# 			y == snake && return 0
# 			sum(abs.(head(y) .- x)) != 1 && return 0
# 			length(y) >= length(snake) && return -1
# 			return 1
# 		end, snakes)), moves)
# 	val, m = findmax(v)
# 	return moves[m]
# end

function nearbigsnake(cell, snake, cells, snakeslist)
	n = filter(x -> x.ishead, neighbours(cell, cells))
	
	length(n) == 0 && return false 
	# length(n) == 1 && n[1] == head(snake) && return false
	S = union((snakes.(n))...)
	pop!(S, id(snake))
	
	return !(isempty(filter(x -> !(snakeslist[x] < snake), S)))
end

nearfood(cell, cells) =
	!isempty(filter(x -> hasfood(x), neighbours(cell, cells)))

function willtailmove(cell, cells, snakeslist)
	isempty(snakes(cell)) && return true # this case doesn't happen though
	# is there an next state where it won't (very pessimistic)
	snake = collect(snakes(cell))[1]
	H = head(snakeslist[snake])
	nf = nearfood(cells[H...], cells)
	return !nf
end

function issafe(cell, snake, cells, snakes) # is the cell safe to take?
	nearbigsnake(cell, snake, cells, snakes) && return false
	
	return isempty(cell.snakes) ||
		 (cell.istail && (tail(snake) == indices(cell) || willtailmove(cell, cells, snakes)))
end

function path(cls, I, J, visited, p=[]; head=false)
	I == J && return true
	!head && length(snakes(cls[I...])) != 0 && return false
	visited[I...] == true && return false
	visited[I...] = true
	
	n = indices.(neighbours(cls[I...], cls))
	length(n) == 0 && return false
	
	dist(x) = sum(abs.(J .- x))
	for ele in sort(n, by=dist)
		visited[ele...] == true && continue
		if path(cls, ele, J, visited, p)
			push!(p, ele)
			return true
		end
	end

	return false
end

function shortest_distance(cls::AbstractArray{Cell,2}, 
	block, food; kwargs...)
	r, c = size(cls)
	visited = fill(false, r, c)
	p = []
	if path(cls, block, food, visited, p; kwargs...)
		return length(p)
	else
		return Inf
	end
end

function astar(s, i)
	snake = s[:snakes][i]
	food = collect(s[:food])
	
	if !snake.alive
		return (0,0)
	end
	
	I = head(snake)
	r, c = s[:height], s[:width]

	dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
	cls = cells(r, c, s[:snakes], food)

	D = filter(x -> in_bounds((I .+ x)..., r, c), dirs)
	
	isempty(D) && return dirs

	safe = filter(x -> issafe(cls[(I .+ x)...], snake, cls, s[:snakes]), D)
	# @show safe, food
	
	isempty(safe) && return D	

	isempty(food) && return safe

	block_food = zeros(length(safe), length(food))

	for i=1:length(safe), j=1:length(food)
		block = I .+ safe[i]
		block_food[i, j] = shortest_distance(cls, block, food[j])
	end
	# @show block_food
	
	r = minimum(block_food)
	good_moves = findall(block_food .== r)
	return map(x -> safe[x[1]], good_moves)
end

function assign(st, N)
	food = collect(st[:food])
	allsnakes = collect(st[:snakes])
	cls = cells(st[:height], st[:width], allsnakes, food)

	snakes = (1:N)[alive.(allsnakes)]
	food_snake = zeros(length(food), length(snakes))
	# @show food, snakes, st[:turn]
	for i=1:length(food), j=1:length(snakes)
		snake = allsnakes[snakes[j]]
		# food_snake[i, j] = sum(abs.(food[i] .- head(snake)))
		food_snake[i, j] = shortest_distance(cls, head(snake), food[i]; head=true)
	end
	foodset = BitSet(1:length(food))
	snakeset = BitSet(1:length(snakes))
	snake_matches = [[] for i=1:length(snakes)]
	snake_match = Any[nothing for i=1:length(snakes)]

	
	while !(isempty(foodset)) && !(isempty(snakeset))
		f = collect(foodset)
		s = collect(snakeset)

		val, indices = findmin(food_snake[f, s], dims=2)
		
		val == Inf && break
		for i=1:length(indices)
			I = indices[i]
			if val[i] == Inf 
				pop!(foodset, f[I[1]])
				continue
			end
			snake = s[I[2]]
			push!(snake_matches[snake], f[I[1]])
		end
		for snake in s
			
			m = snake_matches[snake]
			length(m) == 0 && continue
			pop!(snakeset, snake)
			if length(m) == 1
				
				pop!(foodset, m[1])
				snake_match[snake] = m[1]
				continue
			end

			v, i = findmin(food_snake[m, snake])
			pop!(foodset, m[i])
			snake_match[snake] = m[i]
		end
	end
	moves = [(0, 0) for i=1:N]
	foreach(x -> begin
		snake = snakes[x]
		# @show snake, snake_match[x]
		if snake_match[x] != nothing
	    	f = food[snake_match[x]]
	    	xview = (st..., food=[f],)
	    else
	    	t = tail(allsnakes[snake])
	    	xview = (st..., food=[t],)
	    end

	    m = findmove(xview, snake)    
	    moves[snake] = m
	end, 1:length(snakes))
	
	return moves
end

