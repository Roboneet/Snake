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

mutable struct SnakeBFS
	cells
	snakes
	exploration_set
	generation
end

mutable struct ClusterInfo
	id::Int
	length::Int
	parent::Int
	snake::Int
end

struct SnakeUF
	clusters
end

function gen(bfs::SnakeBFS)
	bfs.generation = bfs.generation + 1
	gen(bfs.cells, bfs.snakes, bfs.generation)
end
function gen(cls::Array{Cell,2}, S::Array{Snake,1}, i::Int)
	for j=1:length(S)
		s = S[j]
		length(s) < i && continue
		if i != 1 || s.trail[i] != s.trail[i + 1]
			t = s.trail[i]
			c = cls[t...]
			# @show t, c, c.snakes 
			isempty(c.snakes) && continue
			pop!(c.snakes)
		end
	end
end

function initialise(cls::Array{Cell,2}, S::Array{Snake,1})
	init = matrix(cls; default=-1)
	exp = Tuple{Int,Int}[]
	roots = Dict{Int,Int}()
	cnt = 1
	gen(cls, S, 1)
	# initial exploration set
	@inbounds for i=length(S):-1:1
		snake = S[i]
		N = neighbours(head(snake), size(cls)...)
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
	N = cnt - 1
	cids = Int[1:N...]
	clens = ones(Int, N)
	return init, SnakeBFS(cls, S, [exp, []], 1), SnakeUF(map(
		x -> ClusterInfo(x, 1, x, roots[x]), 1:N))
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

exp(bfs::SnakeBFS) = bfs.exploration_set

function done(bfs::SnakeBFS)
	return isempty(exp(bfs)[1]) && isempty(exp(bfs)[2])
end

function next(bfs::SnakeBFS)
	!isempty(exp(bfs)[1]) &&
		return popfirst!(exp(bfs)[1])

	k = popfirst!(exp(bfs))
	push!(exp(bfs), k)
	gen(bfs)
	next(bfs)
end

function next(bfs::SnakeBFS, x::Tuple{Int,Int})
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

Base.push!(bfs::SnakeBFS, n::Tuple{Int,Int}) = push!(exp(bfs)[2], n)

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

function reachableclusters(cls::Array{Cell,2}, snks::Array{Snake,1})
	S = filter(alive, snks)
	length(S) == 0 && return zeros(size(cls)), Dict(0=>prod(size(cls)...))

	S = sort(S, by=length)
	init, bfs, uf = initialise(cls, S)

	# exploration
	@inbounds while !done(bfs)
		x = next(bfs)
		N = next(bfs, x)
		v = cluster(init, x)

		for j=1:length(N)
			n = N[j]
			nx, ny = n[1], n[2]
			!canvisit(bfs, n) && continue
			if visited(init, n)
				cls[x...].ishead && continue
				k = cluster(init, n)
				!should_merge(uf, k, v) && continue
				# merge k and v clusters
				merge_cls(uf, k, v)
			else
				cluster!(uf, init, n, parent(uf, v))
				push!(bfs, n)
			end
		end
		# __cls__()
		# println(colorarray(init, x))
		# sleep(0.1)
	end
	# @show ni, r*ci
	roots = Dict{Int, Array{Int,1}}()
	for i=1:length(S)
		roots[S[i].id] = Int[]
	end

	compile!(uf, init, roots)
end
