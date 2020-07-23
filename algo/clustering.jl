#-------------------------------------------------------------------------------
# - BFS with snake order
# - snake based union find
#-------------------------------------------------------------------------------
# roots and cluster ids
# A union find with a condition that cluster should
# have same root ids inorder to be united as one cluster

# - exploration set : bfs
# - roots (i.e snake ) of each cluster : uf
# - cluster id (i.e parent) of each cluster : uf
# - cluster length of each cluster : uf
# - snakes : bfs (initialisation)
# - cells : Graph for bfs
# - result matrix : Graph for union find, visited set for bfs

const RBuf = Array{Int64,2}

mutable struct ExpSet
	current::Array{Tuple{Int,Int},1}
	next::Array{Tuple{Int,Int},1}
end

mutable struct SnakeState
	snake::Snake
	exploration_set::ExpSet
	has_eaten::Bool
	tail_lag::Int
end

mutable struct SnakeBFS
	cells::Array{Cell,2}
	snake_states::Array{SnakeState,1}
	generation::Int
end

mutable struct ClusterInfo
	id::Int
	length::Int
	parent::Int
	snake::Int
end

struct SnakeUF{C}
	clusters::C
end

current(exp::ExpSet) = exp.current
next(exp::ExpSet) = exp.next

function swap!(exp::ExpSet)
	c = current(exp)
	exp.current = exp.next
	exp.next = c
	return exp
end

function Base.push!(exp::ExpSet, ele::Tuple{Int,Int})
	push!(next(exp), ele)
end

function isalive(bfs::SnakeBFS, uf::SnakeUF, v::Int)
	id = uf.clusters[v].snake
	s = filter(x -> x.snake.id == id, snake_states(bfs))
	length(s) == 1 || throw("length(s) = $(length(s)) not possible")
	g = bfs.generation
	return s[1].snake.health > g
end

function gen(bfs::SnakeBFS)
	bfs.generation = bfs.generation + 1
	gen(bfs.cells, bfs.snake_states, bfs.generation)
end

function switch!(exp::ExpSet)
	exp.current = exp.next
	exp.next = []
end

function gen(cls::Array{Cell,2}, S::Array{SnakeState,1}, i::Int)
	for j=1:length(S)
		s = S[j]
		switch!(exp(s))
		
		snake_tail = i - s.tail_lag
		trail = s.snake.trail
		if (length(s.snake) >= snake_tail && 
			!s.has_eaten &&
			(snake_tail != 1 || trail[snake_tail] != trail[snake_tail + 1]))
			t = trail[snake_tail]
			c = cls[t...]
			# @show t, c, c.snakes 
			isempty(c.snakes) && continue
			pop!(c.snakes)
		end
		if s.has_eaten
			s.tail_lag += 1
			s.has_eaten = false
		end
	end
end

function initialise(cls::Array{Cell,2}, S::Array{Snake,1})
	init = matrix(cls; default=-1)
	roots = Dict{Int,Int}()
	cnt = 1
	states = SnakeState[]
	@inbounds for i=1:length(S)
		snake = S[i]
		N = neighbours(head(snake), size(cls)...)
		exp = Tuple{Int,Int}[]
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
		push!(states, SnakeState(snake, ExpSet([], exp), false, 0))
	end
	gen(cls, states, 1)
	N = cnt - 1
	cids = Int[1:N...]
	clens = ones(Int, N)
	return init, SnakeBFS(cls, states, 1), SnakeUF(map(
										  x -> ClusterInfo(x, 1, x, roots[x]), 1:N))
end

struct RCState
	board
	bfs
	uf
end

unwrap(rc::RCState) = (rc.board, rc.bfs, rc.uf,)

function ctop(uf::SnakeUF, c::Int)
	c == -1 && return c
	C = uf.clusters
	p = C[c].parent
	p == c && return c
	k = ctop(uf, p)
	C[c].parent = k
	return k
end

function merge_cls(uf::SnakeUF, k::Int, v::Int)
	C = uf.clusters
	kc = C[k]
	vc = C[v]
	@inbounds begin
		a, b =  kc.length > vc.length ? (k, v) : (v, k)
		at = ctop(uf, a)
		C[b].parent = C[a].parent = at
		C[at].length += C[b].length
		C[b].length = C[a].length = C[at].length
	end
end

function should_merge(uf::SnakeUF, k::Int, v::Int)
	C = uf.clusters
	return !((k == v) ||  # ancestor
			 (C[k].snake != C[v].snake) ||  # a bigger snake reached here first
			 (C[k].parent == C[v].parent)) # already merged
end

snake_states(bfs::SnakeBFS) = bfs.snake_states
function isdone(bfs::SnakeBFS)
	for i=1:length(bfs.snake_states)
		ss = bfs.snake_states[i]
		isdone(ss) || return false
	end
	return true
end

function isdone(exp::ExpSet) 
	return isempty(current(exp)) && isempty(next(exp))
end

exp(sst::SnakeState) = sst.exploration_set

function isdone(sst::SnakeState)
	return isdone(exp(sst))
end

function should_swap(exp::ExpSet)
	return isempty(current(exp))
end

current(ss::SnakeState) = current(exp(ss))

function next(bfs::SnakeBFS)
	should_swap(exp(bfs)) || 
	return popfirst!(current(exp(bfs)))

	swap!(exp(bfs))
	gen(bfs)
	next(bfs)
end

function bfs_neighbours(bfs::SnakeBFS, x::Tuple{Int,Int})
	return neighbours(x, size(bfs.cells)...)
end
cells(bfs::SnakeBFS) = bfs.cells
function canvisit(bfs::SnakeBFS, x::Tuple{Int,Int})
	cell = cells(bfs)[x...]
	return !hassnake(cell)
end

function visited(init::RBuf, n::Tuple{Int,Int})
	return cluster(init, n) != -1
end

function cluster(init::RBuf, n::Tuple{Int,Int})
	init[n...]
end

function cluster!(uf::SnakeUF, init::RBuf, n::Tuple{Int,Int}, k::Int)
	init[n...] = k
	uf.clusters[k].length += 1
end

Base.push!(ss::SnakeState, n::Tuple{Int,Int}) = push!(exp(ss), n)

function compile!(uf::SnakeUF, roots::Dict{Int, Array{Int,1}})
	C = uf.clusters
	for c in C
		p = c.parent
		if p == C[p].parent
			if c.id == p
				push!(roots[c.snake], p)
			end
		else
			ctop(uf, c.id)
		end
	end
end

cluster(uf::SnakeUF, k::Int) = uf.clusters[k]
Base.length(uf::SnakeUF, k::Int) = cluster(uf, k).length

function Base.parent(uf::SnakeUF, c::Int)
	C = uf.clusters
	return C[c].parent
end

function compile!(uf::SnakeUF, init::RBuf, roots::Dict{Int, Array{Int,1}})
	compile!(uf, roots)
	d = Dict{Int,Int}()
	@inbounds for j=1:size(init)[2], i=1:size(init)[1]
		c = cluster(init, (i, j))
		!visited(init, (i, j)) && continue
		k = parent(uf, c)
		init[i, j] = k # final cluster id
		if !haskey(d, k)
			d[k] = length(uf, k)
		end
	end
	return init, d, roots
end

function reachableclusters(cls::Array{Cell,2}, snks::Array{Snake,1}; kwargs...)
	S = filter(alive, snks)
	length(S) == 0 && return zeros(size(cls)), Dict(0=>prod(size(cls)...))

	S = sort(S, by=length, rev=true)
	init, bfs, uf = initialise(cls, S)

	# exploration
	explore!(init, bfs, uf; kwargs...)	

	roots = Dict{Int, Array{Int,1}}()
	for i=1:length(S)
		roots[S[i].id] = Int[]
	end
	res = compile!(uf, init, roots)
	return res
end

function determine_snake_order!(bfs::SnakeBFS)
	sort!(bfs.snake_states,
				by = ss -> length(ss.snake) + ss.tail_lag,
				rev = true,
				alg = Base.Sort.InsertionSort) 
end

function explore!(init, bfs, uf; kwargs...)
	while !isdone(bfs)
		determine_snake_order!(bfs)
		ordered_states = bfs.snake_states

		# println(colorarray(init))
		# readline()
		# __cls__()

		for k=1:length(ordered_states)
			ss = ordered_states[k]
			explore!(init, bfs, uf, ss; kwargs...) 
		end 
		gen(bfs)
	end
end

function explore!(init, bfs, uf, ss; kwargs...)
	c = current(ss)
	for i=1:length(c)
		x = c[i]
		explore!(init, bfs, uf, ss, x; kwargs...)
	end 
end

function maybe_eat(bfs::SnakeBFS, ss::SnakeState, x::Tuple{Int,Int})
	c = bfs.cells
	ss.has_eaten = c[x...].food 
end

function explore!(init, bfs, uf, ss, x; no_merge=false)
	v = cluster(init, x)
	isalive(bfs, uf, v) || return 
	maybe_eat(bfs, ss, x)
	N = bfs_neighbours(bfs, x)

	@inbounds for j=1:length(N)
		n = N[j]
		nx, ny = n[1], n[2]
		!canvisit(bfs, n) && continue
		if visited(init, n)
			bfs.cells[x...].ishead && continue
			k = cluster(init, n)
			(no_merge || !should_merge(uf, k, v)) && continue
			# merge k and v clusters
			merge_cls(uf, k, v)
		else
			cluster!(uf, init, n, parent(uf, v))
			push!(ss, n)
		end
	end		
end

