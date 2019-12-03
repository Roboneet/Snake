include("../env/Snake.jl")

function play(algo, si, N)
	env = SnakeEnv(si, N)
	
	display(env)

	memory = (moves=[], states=[])
	# try 
		while !done(env)
			s = state(env)
			
			moves = findmoves(algo, s, N)
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

xy(k) = (k["y"] + 1,k["x"] + 1)
function state(params::Dict)
    board_p = params["board"]
    height = board_p["height"]
    width = board_p["width"]
    food = Set(xy.(board_p["food"]))
    snakes = Snake[]
    me = 1
    for i=1:length(board_p["snakes"])
        u = board_p["snakes"][i]
        if u["id"] === params["you"]["id"]
            me = i
        end
        trail = reverse(collect(xy.(u["body"])))
        trail = map(p -> in_bounds(p..., height, width) ? 
                    p : nothing, trail)
        if length(trail) > 1
            direction = trail[end] .- trail[end - 1]
        else
            direction = nothing
        end
        push!(snakes, Snake(i, trail, u["health"], true, direction, nothing))
    end
    return (height=height, width=width, food=food,
        snakes=snakes, done=false, turn=params["turn"], me=me)
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
	K = filter(x -> !(snakeslist[x] < snake), S)
	return !(isempty(K))
end

nearfood(cell, cells) =
	!isempty(filter(x -> hasfood(x), neighbours(cell, cells)))

fullhealth(snake) = (health(snake) == SNAKE_MAX_HEALTH)

function willtailmove(cell, cells, snakeslist)
	isempty(snakes(cell)) && return true # this case doesn't happen though
	# is there an next state where it won't (very pessimistic)
	snake = collect(snakes(cell))[1]
	# H = head(snakeslist[snake])
	# nf = nearfood(cells[H...], cells)
	# return !nf
	return !fullhealth(snakeslist[snake]) # has eaten ?
end


freecell(cell, cells, snakes) = isempty(cell.snakes) ||
		 (cell.istail &&  willtailmove(cell, cells, snakes))

# function issafe(cell, snake, cells, snakes) # is the cell safe to take?
# 	nearbigsnake(cell, snake, cells, snakes) && return false
	
# 	return freecell(cell, cells, snakes)
# end

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

# higher order function to run a list of functions until the end or until one of it provides an empty output or there is only one element left
flow(fs...) = flow(fs)
function flow(fs) 
	function br(f, g) 
		return x -> begin
		    l = f(x)
		    isempty(l) && return x
		    length(l) == 1 && return l
		    g(l)
	    end
	end
	foldr(br, fs)
end
choose(f) = y -> filter(f, y)

function biggercluster(I, clusters, cdict)
	return y -> begin
	    K = map(x -> clusters[(I .+ x)...], y)
	    l = map(i -> K[i] != 0 ? cdict[K[i]] : begin
	    	L = (I .+ y[i])
	    	s = maximum(map(x -> clusters[x...], 
	    		neighbours(L, size(clusters)...)))
	    	return s
		end, 1:length(K))
		M = maximum(l)
		return map(x -> x[1], 
			filter(x -> x[2] == M, collect(zip(y, l))))
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

	
	cls = cells(r, c, s[:snakes], food)
	# io = IOBuffer()
	# println(io, s[:turn])
	# showcells(io, cls)
	# println(String(take!(io)))
	# choose(x -> issafe(cls[(I .+ x)...], snake, cls, s[:snakes]))
	clusters, cdict = floodfill(cls)

	pipe = flow(choose(x -> in_bounds((I .+ x)..., r, c)),                   
		choose(x -> freecell(cls[(I .+ x)...], cls, s[:snakes])),            
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])),  
		biggercluster(I, clusters, cdict))  

	safe = pipe(DIRECTIONS)

	length(safe) == 1 && return safe

	health(snake) > SNAKE_MAX_HEALTH*0.75 && (rand() < 0.75) && return safe



	# @show safe, food
	
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

function floodfill(cells)
	r, c = size(cells)
	z = zeros(Int, (r, c,))
	cnt = 1
	pdict = Dict()
	for i=1:r
		for j=1:c
			z[i, j] != 0 && continue
			hassnake(cells[i, j]) && continue
			p = floodfill!(cells, i, j, z, cnt)
			pdict[cnt] = p
			cnt += 1
		end
	end
	return z, pdict
end

function floodfill!(cells, i, j, z, cnt)
	cell = cells[i, j]
	hassnake(cell) && return 0
	z[i, j] = cnt
	p = 1
	ns = collect(neighbours(cell, cells))
	for n in ns
		k, l = indices(n)
		z[k, l] != 0 && continue
		p += floodfill!(cells, k, l, z, cnt)
	end
	return p
end

function assign(st, N, findmove)
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

