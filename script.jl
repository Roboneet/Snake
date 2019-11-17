include("Snake.jl")

function play(N::Int = 4)
	env = SnakeEnv((8, 8), N)
	
	display(env)

	memory = (moves=[], states=[])
	return play(env, memory, N)
end

function play(env, memory::NamedTuple, N)
	# try 
		while !done(env)
			s = state(env)
			
			moves = find_moves(s, N)
			push!(memory[:states], s)
			push!(memory[:moves], moves)
			
			step!(env, moves)
			display(env)
		end
		push!(memory[:states], state(env))
	# catch e
	# 	show(e)
	# end

	return env, memory
end


function find_moves(s, N)
	# return map(x -> find_move(s, x), 1:N)
	return assign(s, N)
end

function find_move(s, i)
	good_moves = astar(s, i)
	return good_moves[1]
end

function path(cls, I, J, visited, p=[])
	# @show I, J
	I == J && return true
	length(snakes(cls[I...])) != 0 && return false
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
	block, food)
	r, c = size(cls)
	visited = fill(false, r, c)
	p = []
	if path(cls, block, food, visited, p)
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

	D = filter(x -> in_bounds((I .+ x)..., r, c) && 
			(length(snakes(cls[(I .+ x)...])) == 0 ||
				# dont worry about my tail, it'll move when I do
				all(tail(snake) .== (I .+ x))), dirs)
	if length(D) == 0
		return rand(dirs, 1)
	end
	if length(food) == 0
		return D
	end

	block_food = zeros(length(D), length(food))

	for i=1:length(D), j=1:length(food)
		block = I .+ D[i]
		block_food[i, j] = shortest_distance(cls, block, food[j])
		# @show block_food[i, j], sum(abs.(block .- food[j]))
	end
	# @show block_food
	r = minimum(block_food)
	good_moves = findall(block_food .== r)
	return map(x -> D[x[1]], good_moves)
end

function assign(st, N)
	food = collect(st[:food])
	allsnakes = collect(st[:snakes])
	snakes = (1:N)[alive.(allsnakes)]
	food_snake = zeros(length(food), length(snakes))
	# @show food, snakes, st[:turn]
	for i=1:length(food), j=1:length(snakes)
		snake = allsnakes[snakes[j]]
		food_snake[i, j] = sum(abs.(food[i] .- head(snake)))
	end
	foodset = BitSet(1:length(food))
	snakeset = BitSet(1:length(snakes))
	snake_matches = [[] for i=1:length(snakes)]
	snake_match = Any[nothing for i=1:length(snakes)]

	
	while !(isempty(foodset)) && !(isempty(snakeset))
		f = collect(foodset)
		s = collect(snakeset)

		val, indices = findmin(food_snake[f, s], dims=2)
		for I in indices
			
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
		if snake_match[x] != nothing
	    	f = food[snake_match[x]]
	    	xview = (st..., food=[f],)
	    else
	    	t = tail(allsnakes[snake])
	    	xview = (st..., food=[t],)
	    end
	    m = find_move(xview, snake)    
	    moves[snake] = m
	end, 1:length(snakes))
	
	return moves
end

