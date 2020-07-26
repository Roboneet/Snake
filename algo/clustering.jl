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

struct RCState
	board
	bfs
	uf
end

unwrap(rc::RCState) = (rc.board, rc.bfs, rc.uf,)
Base.show(io::IO, rc::RCState) = println(io, colorarray(rc.board))

const RBuf = Array{Int64,2} # this probably means Reachable Buffer

mutable struct ExpSet
	current::Array{Tuple{Int,Int},1}
	next::Array{Tuple{Int,Int},1}
end

mutable struct SnakeState
	snake::Snake
	exploration_set::ExpSet
	has_eaten::Bool
	tail_lag::Int
	power_boost::Int
	move::Union{Tuple{Int,Int},Nothing}
end

SnakeState(snake::Snake, h::Array{Tuple{Int,Int},1}, m) = 
SnakeState(snake, ExpSet([], h), false, 0, 0, m)

SnakeState(snake::Snake, m) = SnakeState(snake, Tuple{Int,Int}[], m)

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

ClusterInfo(x, y) = ClusterInfo(x, 1, x, y)

struct SnakeUF{C}
	clusters::C
end

current(exp::ExpSet) = exp.current
next(exp::ExpSet) = exp.next

function Base.push!(exp::ExpSet, ele::Tuple{Int,Int})
	push!(next(exp), ele)
end

function Base.push!(uf::SnakeUF, ele::ClusterInfo)
	push!(uf.clusters, ele)
end

function isalive(bfs::SnakeBFS, ss::SnakeState)
	snake = ss.snake
	return snake.alive && snake.health + ss.power_boost > bfs.generation
end

function switch!(exp::ExpSet)
	exp.current = exp.next
	exp.next = []
end

function gen(bfs::SnakeBFS)
	bfs.generation = bfs.generation + 1
	gen(bfs.cells, bfs.snake_states, bfs.generation)
end 

function gen(cls::Array{Cell,2}, S::Array{SnakeState,1}, i::Int)
	for j=1:length(S)
		s = S[j]
		switch!(exp(s))
		snake_tail = i - s.tail_lag
		# @show s.tail_lag
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
			s.power_boost += 100
		end
	end
end

function create(cls::Array{Cell,2}, S::Array{Snake,1}; moves=map(x->nothing,S))
	# @show moves
	return RCState(matrix(cls; default=-1), 
				   SnakeBFS(cls, map(x -> SnakeState(S[x], moves[x]), 1:length(S)), 0),
				   SnakeUF(ClusterInfo[])
	)
end

markheads(rcstate::RCState) = markheads(rcstate, rcstate.bfs.snake_states)

function markheads(rcstate::RCState, ss::Array{SnakeState,1})
	for s in ss
		markhead(rcstate, s, head(s.snake))
	end
end

function markhead(rcstate::RCState, ss::SnakeState, x::Tuple{Int,Int})
	if rcstate.board[x...] == -1
		rcstate.board[x...] = 0
		push!(ss, x) 
	end
end

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

function bfs_neighbours(bfs::SnakeBFS, ss::SnakeState, x::Tuple{Int,Int}; isspawn::Bool = false)
	# @show isspawn, ss.move
	if isspawn && ss.move != nothing
		m = ss.move .+ x
		return [m]
	end
	return neighbours(x, size(bfs.cells)...)
end
cells(bfs::SnakeBFS) = bfs.cells
function canvisit(bfs::SnakeBFS, x::Tuple{Int,Int})
	cell = cells(bfs)[x...]
	return !hassnake(cell)
end

function visited(init::RBuf, n::Tuple{Int,Int})
	return cluster(init, n) > 0
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

compile(r::RCState) = compile(unwrap(r)...)
function compile(init::RBuf, bfs::SnakeBFS, uf::SnakeUF)
	roots = Dict{Int, Array{Int,1}}()
	S = bfs.snake_states
	for i=1:length(S)
		roots[S[i].snake.id] = Int[]
	end
	return compile!(uf, init, roots)
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
	rcstate = create(cls, snks) 
	markheads(rcstate)
	explore!(rcstate; kwargs...)	
	return compile(rcstate)
end

function determine_snake_order!(bfs::SnakeBFS)
	sort!(bfs.snake_states,
				by = ss -> length(ss.snake) + ss.tail_lag,
				rev = true,
				alg = Base.Sort.InsertionSort) 
end

function determine_snake_order(snakes::Array{Snake,1})
	sort(snakes,
				by = length,
				rev = true,
				alg = Base.Sort.InsertionSort) 
end 

explore!(r::RCState; kwargs...) = explore!(unwrap(r)...; kwargs...)

function explore!(init::RBuf, bfs::SnakeBFS, uf::SnakeUF; kwargs...)
	while !isdone(bfs)
		explore_once!(init, bfs, uf; kwargs...)
	end
end

function explore_once!(init::RBuf, bfs::SnakeBFS, uf::SnakeUF; verbose=false, kwargs...)
	gen(bfs) # move tails
	determine_snake_order!(bfs)
	ordered_states = bfs.snake_states

	for k=1:length(ordered_states)
		ss = ordered_states[k]
		explore!(init, bfs, uf, ss; kwargs...) 
	end 
	if verbose
		println(colorarray(init))
		showcells(stdout, bfs.cells)
		@show bfs.generation
		readline()
		__cls__()
	end
end

function explore!(init, bfs, uf, ss; kwargs...) 
	c = current(ss)
	if !isalive(bfs, ss)
		for i=1:length(c)
			init[c[i]...] = -1
		end
		return
	end
	for i=1:length(c)
		x = c[i]
		explore!(init, bfs, uf, ss, x; kwargs...)
	end 
end

function maybe_eat(bfs::SnakeBFS, ss::SnakeState, x::Tuple{Int,Int})
	c = bfs.cells
	ss.has_eaten = c[x...].food 
	# @show ss.has_eaten
	c[x...].food = false
end

function spawn_cls(init, bfs, uf, ss, x) 
	N = bfs_neighbours(bfs, ss, x; isspawn=true)
	foreach(N) do n
		# @show canvisit(bfs, n)
		canvisit(bfs, n) || return
		visited(init, n) && return
		maybe_eat(bfs, ss, n) 
		cnt = length(uf.clusters) + 1
		init[n...] = cnt
		push!(ss, n)
		push!(uf, ClusterInfo(cnt, id(ss.snake)))
	end
end 

function explore!(init::RBuf, bfs::SnakeBFS, uf::SnakeUF, 
			 ss::SnakeState, x::Tuple{Int,Int})

	v = cluster(init, x)
	if v == 0
		spawn_cls(init, bfs, uf, ss, x) 
		init[x...] = -1
		return
	end
	v == -1 && return

	N = bfs_neighbours(bfs, ss, x) 
	@inbounds for j=1:length(N)
		n = N[j]
		nx, ny = n[1], n[2]
		# init[n...] == 0 && continue # dont visit a prev head
		canvisit(bfs, n) || continue
		if visited(init, n)
			k = cluster(init, n)
			should_merge(uf, k, v) || continue
			merge_cls(uf, k, v)
		else 
			maybe_eat(bfs, ss, n) 
			cluster!(uf, init, n, parent(uf, v))
			push!(ss, n)
		end
	end		
end 
