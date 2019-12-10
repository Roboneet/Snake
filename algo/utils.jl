include("../env/Snake.jl")

using DataStructures

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
			@show moves, algo
			@show length.(state(env).snakes)
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

function nearsnake(cell, snake, cells, snakeslist, cmp)
	n = filter(x -> x.ishead, neighbours(cell, cells))
	
	length(n) == 0 && return false 
	S = union((snakes.(n))...)
	if id(snake) in S
		pop!(S, id(snake))
	end
	K = filter(x -> cmp(snakeslist[x], snake), S)
	return !(isempty(K))
end

nearsmallsnake(args...) = nearsnake(args..., (a, b) -> a < b)
nearbigsnake(args...) = nearsnake(args..., (a, b) -> !(a < b))

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
	return length(snake) >=3 && !fullhealth(snakeslist[snake]) # has eaten ?
end


freecell(cell, cells, snakes) = isempty(cell.snakes) ||
		 (cell.istail &&  willtailmove(cell, cells, snakes))

# function issafe(cell, snake, cells, snakes) # is the cell safe to take?
# 	nearbigsnake(cell, snake, cells, snakes) && return false
	
# 	return freecell(cell, cells, snakes)
# end

function connectionset(r, c)
	connection = Array{Any, 2}(undef, (r, c))
	for i=1:r, j=1:c
		@inbounds connection[i, j] = nothing
	end
	return connection
end

# bi-directional a-star search
function path(cls, I, J; kwargs...)
	r, c = size(cls)
	# visited = fill(false, r, c)
	connection1 = connectionset(r, c)
	connection2 = connectionset(r, c)
	p = []
	@inbounds connection1[I[1], I[2]] = I
	dist = sum(abs.(I .- J))

	explore1 = PriorityQueue{Tuple{Int,Int},Int}(I=>dist)
	explore2 = PriorityQueue{Tuple{Int,Int},Int}(J=>dist)
	haspath = false
	while !haspath && !isempty(explore1) && !isempty(explore2)
		g = dequeue!(explore1)
		N1 = path(cls, g, J, connection1, explore1; kwargs...)
		M1 = map(x -> connection2[x...] != nothing, N1)

		# the first pivot has to be in the shortest path
		# Otherwise, there would've been another pivot which we would've reached earlier
		if any(M1)
			haspath = true
			pivot = N1[M1][1]
			p = collectpath(connection1, connection2, I, J, pivot)
			break
		end

		h = dequeue!(explore2)
		N2 = path(cls, h, I, connection2, explore2; kwargs...)
		M2 = map(x -> connection1[x...] != nothing, N2)
		if any(M2)
			haspath = true
			pivot = N2[M2][1]
			p = collectpath(connection1, connection2, I, J, pivot)
			break
		end

		if connection1[J...] != nothing
			haspath = true
			p = collectpath(connection1, connection2, I, J, J)
			break	
		end
		if connection2[I...] != nothing
			haspath = true
			p = collectpath(connection1, connection2, I, J, I)
			break	
		end
	end

	return haspath, p
end

function collectpath(connection1, connection2, I, J, pivot)
	p = []
	
	t = pivot
	while t != J
		pushfirst!(p, t)
		@inbounds t = connection2[t[1], t[2]]
	end
	t = pivot
	while t != I
		push!(p, t)
		@inbounds t = connection1[t[1], t[2]]
	end

	return p
end


function path(cls, I, J, connection, explore=[]; head=false)
	I == J && return []
	dist(k) = sum(abs.(J .- k))
	@inbounds cell = cls[I[1], I[2]]

	n = indices.(neighbours(cell, cls))
	length(n) == 0 && return
	
	N = filter(t -> begin
	   @inbounds c = connection[t[1], t[2]] 
	   @inbounds k = cls[t[1], t[2]]
	   c == nothing && length(snakes(k)) == 0
	end, n)

	foreach(t -> begin
			@inbounds connection[t[1], t[2]] = I
			enqueue!(explore, t=>dist(t))
	end, N)

	return N
end

function shortest_distance(cls::AbstractArray{Cell,2}, 
	block, food; kwargs...)
	haspath, p = path(cls, block, food; kwargs...)
	return haspath ? length(p) : Inf
end

# higher order function to run a list of functions until the end or until one of it provides an empty output or there is only one element left
flow(f::Function) = flow((f,))
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
	foldr(br, fs, init=identity)
end
choose(f) = y -> filter(f, y)
through(p, f) = y -> (p ? f(y) : y)

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

function directionpipe(s, i, t)
	snake = s[:snakes][i]
	food = collect(s[:food])
	I = head(snake)
	r, c = s[:height], s[:width]

	cls = cells(r, c, s[:snakes], food)
	directionpipe(s, i, cls, I, t != nothing)
end

function directionpipe(s, i, cls, I, clusterify=true)
	snake = s[:snakes][i]
	clusters, cdict = floodfill(cls)
	return (flow(choose(x -> in_bounds((I .+ x)..., s[:height], s[:width])),                   
		choose(x -> freecell(cls[(I .+ x)...], cls, s[:snakes])),            
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])),  
		through(clusterify, biggercluster(I, clusters, cdict)),
		choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s[:snakes]))) # may return 0 elements 
	)(DIRECTIONS)
end

astar(s, i, t) = astar(s, i, t, directionpipe(s, i))

function astar(s::NamedTuple, i, t, dir)
	snake = s[:snakes][i]
	!snake.alive && return 0

	I = head(snake)
	cls = cells(s)
	food = t != nothing 
	return  food ? astar(cls, I, [t], dir) : astar(cls, I, [tail(snake)], dir)
end

function astar(cls::AbstractArray{Cell,2}, I, Js, dir)
	length(dir) == 1 && return dir
	isempty(Js) && return dir
	
	block_food = zeros(length(dir), length(Js))
	for i=1:length(dir), j=1:length(Js)
		block = I .+ dir[i]
		block_food[i, j] = shortest_distance(cls, block, Js[j])
	end
	
	r = minimum(block_food)
	good_moves = findall(block_food .== r)
	return map(x -> dir[x[1]], good_moves)
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
	targets = Any[nothing for i=1:N]
	foreach(x -> begin
		snake = snakes[x]
	 	if snake_match[x] != nothing
	 		targets[snake] = food[snake_match[x]]
	 	end
	end, 1:length(snakes))
	return targets
end


function distancematrix(c, src)
   r, ci = size(c)
   m = Array{Any,2}(undef, (r, ci))
   for i=1:r, j=1:ci
       m[i, j] = nothing
   end
   e = [src]
   m[src...] = 0.0
   maxl = Inf
   while !isempty(e)
       g = popfirst!(e)
       N = neighbours(g, r, ci)
       v = m[g...]
       for n in N
           if m[n...] == nothing
               if hassnake(c[n...])
                   m[n...] = maxl
               else
                   m[n...] = v + 1
                   push!(e, n)
               end
           end
       end
   end
   m[src...] = maxl
   return m
end

function partition(snakes, ms)
   ml = maximum(id.(snakes)) + 1
   r, c = size(ms[1])
   M = Array{Any,2}(nothing, (r, c))
   for i=1:r, j=1:c
       V = [ms[k][i, j] for k=1:length(snakes)]
       if all(V .== nothing)
           M[i, j] = ml
           continue
       end
       v = V[V .!= nothing]

       p, o = findmin(v)
       O = (1:length(snakes))[V .!= nothing]
       if all(v .== Inf)
           M[i, j] = ml
       elseif count(v .== p) != 1
           S = snakes[V .== p]
           L = length.(S)
           q, m = findmax(L)
           if count(L .== q) != 1
               M[i, j] = ml
           else
               M[i, j] = id(S[m])
           end
       else
           M[i, j] = id(snakes[V .== p][1])
       end
   end
   return M
end

