using DataStructures

__cls__(io=stdout) = print(io, "\x1b[H\x1b[2J")
cls(args...) = __cls__(args...)
cursor_top(io) = print(io, "\x1b[H")

T = Dict((1, 0)=>"down", (-1, 0)=>"up",
	(0, 1)=>"right", (0, -1)=>"left", (0, 0)=>"___")
S = Dict((1, 0)=>"↓", (-1, 0)=>"↑",
	(0, 1)=>"→", (0, -1)=>"←", (0, 0)=>"_")
eng(x) = T[x]
eng(x::AbstractArray) = eng.(x)
sign(x) = S[x]
sign(x::AbstractArray) = sign.(x)

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

function nearsnake(cell::Cell, snake::Snake, cells, snakeslist, cmp)
	n = filter(x -> x.ishead, neighbours(cell, cells))

	length(n) == 0 && return false
	S = union((snakes.(n))...)
	if id(snake) in S
		S = S[S .!= id(snake)]
	end
	K = filter(x -> cmp(snakeslist[x], snake), S)
	return !(isempty(K))
end

nearsmallsnake(args...) = nearsnake(args..., (a, b) -> a < b)
nearbigsnake(args...) = nearsnake(args..., (a, b) -> !(a < b))

nearfood(cell::Cell, cells) =
	!isempty(filter(x -> hasfood(x), neighbours(cell, cells)))

fullhealth(snake::Snake) = (health(snake) == SNAKE_MAX_HEALTH)

function willtailmove(cell::Cell, cells, snakeslist)
	isempty(snakes(cell)) && return true # this case doesn't happen though
	# is there an next state where it won't (very pessimistic)
	snake = snakeslist[collect(snakes(cell))[1]]
	# H = head(snakeslist[snake])
	# nf = nearfood(cells[H...], cells)
	# return !nf
	# return length(snake) >= 3 && !fullhealth(snake) # has eaten ?
	return snake.trail[2] != snake.trail[1]
end


freecell(cell::Cell, cells, snakes) = isempty(cell.snakes) ||
		 (cell.istail &&  willtailmove(cell, cells, snakes))

# function issafe(cell, snake, cells, snakes) # is the cell safe to take?
# 	nearbigsnake(cell, snake, cells, snakes) && return false

# 	return freecell(cell, cells, snakes)
# end

function connectionset(r::Int, c::Int)
	connection = Array{Union{Nothing,Tuple{Int,Int}},2}(undef, (r, c))
	for j=1:c, i=1:r
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
	# @show I
	@inbounds cell = cls[I[1], I[2]]

	n = indices.(neighbours(cell, cls))
	length(n) == 0 && return

	N = filter(t -> begin
	   @inbounds c = connection[t[1], t[2]]
	   @inbounds k = cls[t[1], t[2]]
	   c != nothing && return false
	   length(snakes(k)) == 0 && return true
	   # @show head, t, J
	   head && (t == J)
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
	snake = s.snakes[i]
	food = collect(s.food)
	I = head(snake)
	r, c = height(s), width(s)

	cls = cells(r, c, s.snakes, food)
	directionpipe(s, i, cls, I, t != nothing)
end

function canmove(s::SType, i::Int, I, cls)
	!alive(s.snakes[i]) && return ((y) -> [(0, 0)],)
	return choose(x -> in_bounds((I .+ x)..., height(s), width(s))),
		choose(x -> freecell(cls[(I .+ x)...], cls, s.snakes))
end

function canmove(s::SType, i)
	I = head(s.snakes[i])
	cls = cells(s)
	return canmove(s, i, I, cls)
end

function directionpipe(s::SType, i::Int, cls, I, clusterify=true)
	snake = s.snakes[i]
	clusters, cdict = floodfill(cls)
	return (flow(canmove(s, i, I, cls)...,
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s.snakes)),
		through(clusterify, biggercluster(I, clusters, cdict)),
		choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s.snakes))) # may return 0 elements
	)(DIRECTIONS)
end

astar(s::SType, i::Int, t) = astar(s, i, t, directionpipe(s, i))

function astar(s::SType, i::Int, t, dir; kwargs...)
	snake = s.snakes[i]
	!snake.alive && return 0

	I = head(snake)
	cls = cells(s)
	food = t != nothing
	return  food ? astar(cls, I, [t], dir; kwargs...) : astar(cls, I, [tail(snake)], dir; kwargs...)
end

function astar(cls::AbstractArray{Cell,2}, I, Js, dir; kwargs...)
	length(dir) <= 1 && return dir
	isempty(Js) && return dir

	block_food = zeros(length(dir), length(Js))
	for j=1:length(Js), i=1:length(dir)
		block = I .+ dir[i]
		# @show dir[i], kwargs
		# @show block, Js[j]
		block_food[i, j] = shortest_distance(cls, block, Js[j]; kwargs...)
	end
	# @show dir
	# @show block_food

	r = minimum(block_food)
	good_moves = findall(block_food .== r)
	return unique(map(x -> dir[x[1]], good_moves))
end

floodfill(s::SType, i=nothing) = floodfill(cells(s))

function floodfill(cells)
	r, c = size(cells)
	z = zeros(Int, (r, c,))
	cnt = 1
	pdict = Dict()
	for j=1:c
		for i=1:r
			z[i, j] != 0 && continue
			hassnake(cells[i, j]) && continue
			p = floodfill!(cells, i, j, z, cnt)
			pdict[cnt] = p
			cnt += 1
		end
	end
	return z, pdict
end

function floodfill!(cells, I, J, z, cnt)
	exp = [(I, J)]
	z[I, J] = cnt
	p = 0
	r, c = size(cells)
	while !isempty(exp)
		p += 1
		i, j = pop!(exp)


		ns = neighbours((i, j), r, c)

		for n in ns
			k, l = n
			hassnake(cells[k, l]) && continue
			z[k, l] != 0 && continue

			z[k, l] = cnt
			pushfirst!(exp, (k, l))
		end
	end
	return p
end

function assign(st)
	food = collect(st.food)

	allsnakes = collect(st.snakes)
	N = length(allsnakes)
	cls = cells(height(st), width(st), allsnakes, food)

	snakes = (1:N)[alive.(allsnakes)]
	food_snake = zeros(length(food), length(snakes))
	# @show food, snakes, st[:turn]
	for j=1:length(snakes), i=1:length(food)
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

# struct Tailer # :D, an error prone approach to make things better sometimes
# 	k
# end

# reach(t::Tailer, n) = t.k <= n # reachable using a path of length n

function matrix(c, S=[], followtails=true; default::T=-1.0) where T
	r, ci = size(c)
	m = Array{T,2}(undef, (r, ci))
	for j=1:ci, i=1:r
		m[i, j] = default
	end
	# if followtails
	# 	foreach(S) do x
	# 		t = x.trail
	# 		for i=1:length(t)
	# 			m[t[i]...] = Tailer(i)
	# 		end
	# 	end
	# end
	return m
end
function distancematrix(s::SType, i::Int, heads=false)
	cls = cells(s)
	init = matrix(cls, s.snakes; default=-1)
	sh = heads ? head.(s.snakes) : nothing
	distancematrix(cls, head(s.snakes[i]), init, health(s.snakes[i]), sh)
end
function distancematrix(c, src::T, m, maxsteps=SNAKE_MAX_HEALTH, heads=nothing) where T <: Tuple{Int,Int}
	r, ci = size(c)
	q = Queue{T}()
	enqueue!(q, src)
	@inbounds m[src...] = 0.0
	maxl = SNAKE_MAX_HEALTH + 1
	@inbounds while !isempty(q)
		g = dequeue!(q)
		m[g...] >= maxsteps && continue
		N = neighbours(g, r, ci)
		v = m[g...] + 1
		for n in N
			if m[n...] == -1.0
				if hassnake(c[n...])
					m[n...] = maxl
				else
					m[n...] = v
					enqueue!(q, n)
				end
			# elseif isa(m[n...], Tailer)
			# 	if reach(m[n...], v)
			# 		m[n...] = v
			# 		push!(e, n)
			# 	end
			end
		end
	end
	if heads != nothing
		for h in heads
			N = neighbours(h, r, ci)
			M = filter(x -> x != -1,
				map(n -> m[n...], N))
			isempty(M) && continue
			v = minimum(M) + 1
			v > maxsteps && continue
			m[h...] = v
		end
	end

	@inbounds m[src...] = maxl
	# for i=1:r, j=1:ci
	# 	if isa(m[i, j], Tailer)
	# 		m[i, j] = maxl
	# 	end
	# end
	return m
end

function partition(snakes::AbstractArray{Snake,1}, ms::AbstractVector{<:AbstractArray{Float64,2}})
   ml = maximum(id.(snakes)) + 1
   length(ms) < 1 && error() # AaAaaaaaah
   r, c = size(ms[1])
   M = fill(ml, (r, c))
   maxv = r*c + 1.0
   @inbounds for j=1:c, i=1:r
       v = maxv
       for k=1:length(snakes)
       	o = ms[k][i, j]
       	o == -1.0 && continue
       	# @show k, o, v
       	if o < v
       		M[i, j] = k
       		v = o
       	elseif o == v
       		if length(snakes[k]) > length(snakes[M[i, j]])
       			M[i, j] = k
       			v = o
       		end
       	end

       end
   end
   return M
end


function reachableclusters(s::SType, i=nothing)
	cls = cells(s)
	return reachableclusters(cls, s.snakes)
end


function colorarray(g, x = (-1, -1))
	r, c = size(g)
	bc = Crayon(background=:black)
	df = Crayon(background=:default, foreground=:default)
	io = IOBuffer()
	num_rep = (x) -> lpad(x == -1 ? "" : "$(x) ", 3)
	foreach( i -> begin
		foreach( y -> print(io, y[2], (i,y[1]) == x ? " ▤⃝ " : num_rep(g[i, y[1]])),
			map(j -> g[i, j] == -1 ? (j, bc,) :
			(j, Crayon(background=SNAKE_COLORS[g[i, j]],
				foreground=:white),), 1:c))
		println(io, df)
		end, 1:r)
	String(take!(io))
end

function reachableclusters(cls::Array{Cell,2}, snks::Array{Snake,1})
	S = filter(alive, snks)
	r, ci = size(cls)
	length(S) == 0 && return zeros(size(cls)), Dict(0=>r*ci)
	init = matrix(cls; default=-1)
	ss = sort(S, by=length)
	exp = Tuple{Int,Int}[]
	roots = Dict{Int,Int}()
	l = length(ss)
	cnt = 1
	@inbounds for i=l:-1:1
		snake = ss[i]
		N = neighbours(head(snake), r, ci)
		foreach(N) do n
			nx, ny = n[1], n[2]
			init[nx, ny] != -1 && return
			cell = cls[nx, ny]
			hassnake(cell) && return
			roots[cnt] = id(snake)
			init[nx, ny] = cnt
			push!(exp, n)
			cnt += 1
		end
	end
	cids = Int[1:(cnt - 1)...]
	clens = ones(Int, cnt - 1)
	function ctop(c::Int)
		c == -1 && return c
		@inbounds while cids[c] != c
			c = cids[c]
		end
		return c
	end
	function merge_cls(k::Int, v::Int)
		@inbounds begin
			a, b =  clens[k] > clens[v] ? (k, v) : (v, k)
			at = ctop(a)
			cids[b] = cids[a] = at
			clens[at] += clens[b]
			clens[b] = clens[a] = clens[at]
		end
	end
	ni = 0
	@inbounds while !isempty(exp)
		ni += 1
		x = popfirst!(exp)
		N = neighbours(x, r, ci)
		v = init[x[1], x[2]]
		rt = roots[v]
		xn = 0

		for j=1:length(N)
			n = N[j]
			nx, ny = n[1], n[2]
			cell = cls[nx, ny]
			hassnake(cell) && continue
			k = init[nx, ny]
			if k != -1
				k == v && continue # ancestor
				roots[k] != rt && continue # a bigger snake reached here first
				cids[k] == cids[v] && continue # already merged
				# merge k and v clusters
				merge_cls(k, v)

			else
				init[nx, ny] = cids[v]
				clens[v] += 1
				push!(exp, n)
				xn += 1
			end
		end
		# __cls__()
		# println(colorarray(init, x))
		# sleep(0.1)
	end
	# @show ni, r*ci
	d = Dict{Int,Int}()
	@inbounds for j=1:ci, i=1:r
		c = init[i, j]
		if c != -1
			c = ctop(c)
			init[i, j] = c # final cluster id
		end
		if !haskey(d, c)
			d[c] = 0
		end
		d[c] += 1
	end
	return init, d
end
#
# function reachableclusters(cls, snks)
# 	S = filter(alive, snks)
# 	length(S) == 0 && return zeros(size(cls)), Dict()
# 	init = matrix(cls, S)
# 	l = length(S)
# 	d = Array{typeof(init),1}(undef, l)
# 	@inbounds for i=1:l
# 		x = S[i]
# 		d[i] = distancematrix(cls, head(x), copy(init), health(x))
# 	end
# 	M, N = size(cls)
# 	partitions = partition(S, d)
# 	flooded, fdict = floodfill(cls)
#
# 	clusters = Array{Int,2}(undef, (M, N))
#
# 	u = Dict{Int,Dict{Int,Int}}()
#
# 	cnt = 1
# 	@inbounds for j=1:N, i=1:M
# 		if hassnake(cls[i, j])
# 			clusters[i, j] = 0
# 		else
# 			p = partitions[i, j]
# 			if !haskey(u, p)
# 				u[p] = Dict{Int,Int}()
# 			end
# 			f = flooded[i, j]
# 			if !haskey(u[p], f)
# 				u[p][f] = cnt
# 				cnt += 1
# 			end
# 			clusters[i, j] = u[p][f]
# 		end
# 	end
#
# 	cdict = Dict{Int,Int}()
#
# 	@inbounds for j=1:N, i=1:M
# 		c = clusters[i, j]
# 		if !haskey(cdict, c)
# 			cdict[c] = 0
# 		end
#
# 		cdict[c] += 1
# 	end
# 	return clusters, cdict
# end
