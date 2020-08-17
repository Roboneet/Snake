# TODO: Design Doc
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

function gradient(S, E, n)
	d(x, y, i) = floor(Int, (y[i] - x[i])/n)
	D = (d(S, E, 1), d(S, E, 2), d(S, E, 3))
	map(x -> S .+ (x - 1).*D, 1:n) 
end

function arraygradient(arr, S, E)
	colorarray(arr, (-1, -1), 
	gradient(S, E, maximum(arr))
	)
end

function Base.show(io::IO, rc::RCState) 
	println(io, arraygradient(rc.board, (0, 242, 96), (5, 117, 230)))
	# println(io, arraygradient(rc.bfs.gboard, (201, 75, 75), (75, 19, 79))) 
end

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
	food_available::Int
	power_boost::Int
	move::Union{Tuple{Int,Int},Nothing}
end

SnakeState(snake::Snake, h::Array{Tuple{Int,Int},1}, m) = 
SnakeState(snake, ExpSet([], h), false, 0, 0, 0, m)

SnakeState(snake::Snake, m) = SnakeState(snake, Tuple{Int,Int}[], m)

mutable struct SnakeBFS
	cells::Array{Cell,2}
	snake_states::Array{SnakeState,1}
	generation::Int
	hero::Int
	gboard::RBuf # keeps track of the generation at which a cell is visited
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
		trail = s.snake.trail

		# @show s.tail_lag, snake_tail, length(trail)
		if (length(s.snake) >= snake_tail && 
			!s.has_eaten &&
			(snake_tail != 1 || trail[snake_tail] != trail[snake_tail + 1]))
			t = trail[snake_tail]
			# @show t
			c = cls[t...]
			# @show t, c, c.snakes 
			isempty(c.snakes) && continue
			id(s.snake) in c.snakes || continue
			pop!(c.snakes)
		end
		if s.has_eaten
			s.tail_lag += 1
			s.has_eaten = false
			s.power_boost += 100
		end
	end
end

function create(cls::Array{Cell,2}, S::Array{Snake,1}; 
				moves=map(x->nothing,S), hero=1, kwargs...)
	# @show moves
	return RCState(matrix(cls; default=-1), 
				   SnakeBFS(cls, 
							map(x -> SnakeState(S[x], moves[x]), 1:length(S)),
							0, hero, matrix(cls; default=-1)),
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
	if isalive(rcstate.bfs, ss) && rcstate.board[x...] == -1
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
	(k == -1 || v == -1) && return false
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
	if isspawn && ss.move !== nothing
		m = ss.move .+ x
		return [m]
	end
	return neighbours(x, size(bfs.cells)...)
end

function get_snake_state_by_id(bfs, i)
	for x in bfs.snake_states
		if i == id(x.snake)
			return x
		end
	end
end

function canvisit(bfs::SnakeBFS, x::Tuple{Int,Int})
	cell = bfs.cells[x...]
	cell.hazardous && return false
	s = snakes(cell)
	isempty(s) && return true
	i = s[1]
	return !isalive(bfs, get_snake_state_by_id(bfs, i))
end

function visited(bfs::SnakeBFS, n::Tuple{Int,Int})
	# return cluster(init, n) > 0
	return bfs.gboard[n...] != -1
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
import Base: length
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
		c > 0 || continue
		k = parent(uf, c)
		init[i, j] = k # final cluster id
		if !haskey(d, k)
			d[k] = length(uf, k)
		end
	end
	return init, d, roots
end

function reachableclusters(cls::Array{Cell,2}, snks::Array{Snake,1}; kwargs...)
	rcstate = create(cls, snks; kwargs...) 
	markheads(rcstate)
	explore!(rcstate; kwargs...)	
	return compile(rcstate)
end

function sortValue(ss::SnakeState, i::Int)
	v = length(ss.snake) + ss.tail_lag
	# if ss.snake.id == i
	# 	v += 0.1
	# end 
	return v
end 

function determine_snake_order!(bfs::SnakeBFS)
	sp = bfs.hero
	sort!(bfs.snake_states,
		  by = ss -> sortValue(ss, sp),
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
	if c[x...].food
		ss.has_eaten = true
		ss.food_available += 1
		c[x...].food = false
	end
end

function markgen(bfs::SnakeBFS, x::Tuple{Int,Int})
	bfs.gboard[x...] = bfs.generation
end

root(uf::SnakeUF, v::Int) = uf.clusters[v].snake
rootsnake(bfs::SnakeBFS, r::Int) = filter(x -> id(x.snake) == r, bfs.snake_states)[1]
compute_len(rs::SnakeState) = rs.tail_lag + length(rs.snake)

# incase snakes with equal lengths visit a spot
function should_unvisit(init, bfs, uf, ss, x)
	bfs.generation != bfs.gboard[x...] && return false
	v = cluster(init, x)
	r = root(uf, v)
	r == ss.snake.id && return false
	rs = rootsnake(bfs, r)
	# println("should_unvisit $x $(ss.snake.id) $r")
	return compute_len(rs) == compute_len(ss)
end

function destroy(init::RBuf, x::Tuple{Int,Int})
	# println("destroy $x")
	init[x...] = -1
end

function is_destroyed(init::RBuf, n::Tuple{Int, Int})
	return init[n...] == -1
end

function spawn_cls(init::RBuf, bfs::SnakeBFS, uf::SnakeUF, ss::SnakeState, x::Tuple{Int,Int}) 
	N = bfs_neighbours(bfs, ss, x; isspawn=true)
	foreach(N) do n
		canvisit(bfs, n) || return
		if visited(bfs, n) 
			is_destroyed(init, n) && return
			should_unvisit(init, bfs, uf, ss, n) || return
			destroy(init, n)
		else
			maybe_eat(bfs, ss, n) 
			cnt = length(uf.clusters) + 1
			init[n...] = cnt
			push!(ss, n)
			push!(uf, ClusterInfo(cnt, id(ss.snake)))
			markgen(bfs, n)
		end
	end
end 

function explore!(init::RBuf, bfs::SnakeBFS, uf::SnakeUF, 
			 ss::SnakeState, x::Tuple{Int,Int}; kwargs...) 
	v = cluster(init, x)
	if v == 0
		spawn_cls(init, bfs, uf, ss, x) 
		destroy(init, x)
		return
	end
	is_destroyed(init, x) && return

	N = bfs_neighbours(bfs, ss, x) 
	@inbounds for j=1:length(N)
		n = N[j]
		nx, ny = n[1], n[2]
		# init[n...] == 0 && continue # dont visit a prev head
		canvisit(bfs, n) || continue
		if visited(bfs, n)
			is_destroyed(init, n) && continue
			k = cluster(init, n)
			if should_merge(uf, k, v) 
				merge_cls(uf, k, v)
			elseif should_unvisit(init, bfs, uf, ss, n)
				destroy(init, n)
			end
		else 
			maybe_eat(bfs, ss, n) 
			cluster!(uf, init, n, parent(uf, v))
			push!(ss, n)
			markgen(bfs, n)
		end
	end		
end 
