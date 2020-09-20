# VERSION C
# a cellular automata version of clusterify

struct SnakefillC <: AbstractSnakefill
	visit::Int # tick at which this block was visited
	food::Bool # true if block has food
	health::UInt8 # maximum health possible when visiting
	length::UInt8 # maximum length possible when visiting
	clusterId::UInt8
	visitor::UInt8
end

SnakefillC(l, s) = SnakefillC(l, false, 0, 0, 0, s)
visit(sf::SnakefillC) = sf.visit
hasfood(sf::SnakefillC) = sf.food
cluster(sf::SnakefillC) = sf.clusterId
visitor(sf::SnakefillC) = sf.visitor
Base.length(sf::SnakefillC) = sf.length
health(sf::SnakefillC) = sf.health

mutable struct ClusterInfoB
	clusterId::UInt8
	root::UInt8
end

mutable struct SnakeTrack
	maxlength::Int
	nextlength::Int
end
SnakeTrack(n) = SnakeTrack(n, n)

mutable struct SnakefillCGlobal
	tick::UInt8
	snaketrack::Array{SnakeTrack,1}
	clusters::Array{ClusterInfoB,1}
end

function Base.show(io::IO, c::Grid{SnakefillC, SnakefillCGlobal})
	st = states(c)
	v = visit.(st)
	maxlength = maximum(map(x -> x.maxlength, c.global_state.snaketrack))
	m = v .- (-1 * maxlength + c.global_state.tick)
	fint = x -> floor(Int, x)
	color = x -> fint.((x.r*255, x.g*255, x.b*255))
	color_palette = range(colorant"#a26fbb", colorant"#17847f", length=max(maximum(m), 3))
	println(io, maxlength)
	print(io, colorarray(m, Tuple.(findall(hasfood.(st))), color.(color_palette)))
end

function showprop(c::Grid{SnakefillC}, f, l=nothing)
	st = states(c)
	v = Int.(f.(st))
	fint = x -> floor(Int, x)
	color = x -> fint.((x.r*255, x.g*255, x.b*255))
	if l == nothing
		l = max(maximum(v) - minimum(v), 3)
	end
	color_palette = range(colorant"#a26fbb", colorant"#17847f", length=l)
	println(colorarray(v, [], color.(color_palette)))
end


function createCA(::Type{SnakefillC}, st::SType)
	h, w = height(st), width(st)
	states = Array{SnakefillC,2}(undef, h, w)
	l = -maximum(map(x -> length(x.trail), st.snakes))
	for j=1:w, i=1:h
		states[i, j] = SnakefillC(l, 0)
	end
	for snake in st.snakes
		tr = trail(snake)
		for i=1:length(tr)
			visit = i - length(tr)
			hl = health(snake)
			len = length(tr)
			old = states[tr[i]...]
			states[tr[i]...] = SnakefillC(visit, false, hl, len, old.clusterId, id(snake))
		end
	end
	food = st.food
	for i=1:length(food)
		old = states[food[i]...] 
		states[food[i]...] = SnakefillC(l, true, old.health, old.length, old.clusterId, old.visitor)
	end
	fn = (i, j) -> begin
		n = neighbours((i, j), h, w)
		map(x -> h*(x[2] - 1) + x[1], n)
	end
	snaketrack = map(x -> SnakeTrack(length(x)), st.snakes)
	gs = SnakefillCGlobal(0, snaketrack, ClusterInfoB[])
	return Grid(states, fn, gs)
end

function CA.update_global!(::Type{SnakefillC}, gs::SnakefillCGlobal)
	for sn in gs.snaketrack
		sn.maxlength = sn.nextlength
	end
	gs.tick += 1
end

hasheadandalive(gs::SnakefillCGlobal) = n -> (n.visit == gs.tick - 1) && (n.health > gs.tick)

function __findmax(f, heads::Array{T,1}) where {T<:AbstractSnakefill} 
	l = map(f, heads)
	L = maximum(l)
	h = heads[l .== L]
end

function chooseheads(::Type{SnakefillC}, heads::Array{SnakefillC,1}, gs::SnakefillCGlobal)
	# no head
	isempty(heads) && return heads
	# just one head
	length(heads) == 1 && return heads
	
	# pick a visitor
	v = visitor.(heads)
	if length(unique(v)) != 1
		bestvisitors = __findmax(length, heads)
		if length(bestvisitors) != 1 && length(unique(visitor.(bestvisitors))) != 1
			# head on head collision of same length snakes
			return SnakefillC[]
		end
	else
		bestvisitors = heads
	end

	r = roots(gs, bestvisitors)

	# find head with max length
	h = __findmax(length, bestvisitors)

	# the max health one
	k = __findmax(health, h)

	if length(unique(r)) != 1	
		kr = root(gs, k[1])
		for i=1:length(r)
			if r[i] != kr
				setroot!(gs, r[i], kr)
			end
		end
	end
	return k
end

function createCluster!(gs::SnakefillCGlobal)
	cls = gs.clusters
	n = length(cls) + 1
	push!(cls, ClusterInfoB(n, n))
	return n
end

function setroot!(gs::SnakefillCGlobal, a::UInt8, b::UInt8)
	gs.clusters[a].root = b
end

function roots(gs::SnakefillCGlobal, heads::Array{SnakefillC,1})
	return (x -> root(gs, x)).(cluster.(heads))
end

root(gs::SnakefillCGlobal, head::SnakefillC) = root(gs, head.clusterId)
function root(gs::SnakefillCGlobal, n::UInt8)
	n == 0 && return n
	gs.clusters[n].root == n && return n
	r = root(gs, gs.clusters[n].root)
	gs.clusters[n].root = r
	return r
end

function isoccupied(sf::SnakefillC, gs::SnakefillCGlobal)
	sf.visitor == 0 && return false
	maxlength = gs.snaketrack[sf.visitor].maxlength
	return sf.visit + maxlength > gs.tick
end

# assign values to nf rather than allocating new memory
function CA.step(sf::SnakefillC, n::Array{SnakefillC,1}, gs::SnakefillCGlobal)	
	visit = sf.visit
	food = sf.food
	hl = sf.health
	len = sf.length
	clusterId = sf.clusterId
	visitor = sf.visitor

	if !(isoccupied(sf, gs) || everoccupied(sf))
		heads = n[hasheadandalive(gs).(n)]
		H = chooseheads(SnakefillC, heads, gs)
		if !isempty(H)
			h = H[1]
			if h.clusterId == 0
				clusterId = createCluster!(gs)
			else
				clusterId = root(gs, h.clusterId)
			end
			hl = h.health
			len = h.length
			visit = gs.tick
			visitor = h.visitor
			if food 
				food = false
				hl = SNAKE_MAX_HEALTH + gs.tick
				len = len + 1
				track = gs.snaketrack[visitor]
				if len > track.nextlength
					track.nextlength = len
				end
			end
		end
	end

	return SnakefillC(visit, food, hl, len, clusterId, visitor)
end


