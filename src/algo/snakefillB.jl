# VERSION B
# a cellular automata version of clusterify's bfs with 1 snake
# with clustering

struct SnakefillB <: AbstractSnakefill
	visit::Int # tick at which this block was visited
	food::Bool # true if block has food
	health::UInt8 # maximum health possible when visiting
	length::UInt8 # maximum length possible when visiting
	clusterId::UInt8
end

SnakefillB(l) = SnakefillB(l, false, 0, 0, 0)
visit(sf::SnakefillB) = sf.visit
hasfood(sf::SnakefillB) = sf.food
cluster(sf::SnakefillB) = sf.clusterId

mutable struct ClusterInfoB
	clusterId::UInt8
	root::UInt8
end

mutable struct SnakefillBGlobal
	tick::UInt8
	maxlength::UInt8
	nextlengths::Array{UInt8,1}
	clusters::Array{ClusterInfoB,1}
end

function Base.show(io::IO, c::Grid{SnakefillB, SnakefillBGlobal})
	st = states(c)
	v = visit.(st)
	m = v .- (-1 * Int(c.global_state.maxlength) + c.global_state.tick)
	fint = x -> floor(Int, x)
	color = x -> fint.((x.r*255, x.g*255, x.b*255))
	color_palette = range(colorant"#a26fbb", colorant"#17847f", length=max(maximum(m), 3))
	println(io, c.global_state.maxlength)
	print(io, colorarray(m, Tuple.(findall(hasfood.(st))), color.(color_palette)))
end

function showprop(c::Grid{SnakefillB}, f, l=nothing)
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


function createCA(::Type{SnakefillB}, st::SType)
	h, w = height(st), width(st)
	states = Array{SnakefillB,2}(undef, h, w)
	snake = st.snakes[1]
	tr = trail(snake)
	l = -length(tr)
	for j=1:w, i=1:h
		states[i, j] = SnakefillB(l)
	end
	for i=1:length(tr)
		visit = i - length(tr)
		hl = health(snake)
		len = length(tr)
		old = states[tr[i]...]
		states[tr[i]...] = SnakefillB(visit, false, hl, len, old.clusterId)
	end
	food = st.food
	for i=1:length(food)
		old = states[food[i]...] 
		states[food[i]...] = SnakefillB(l, true, 0, 0, old.clusterId)
	end
	fn = (i, j) -> begin
		n = neighbours((i, j), h, w)
		map(x -> h*(x[2] - 1) + x[1], n)
	end
	gs = SnakefillBGlobal(0, length(snake), Int[], ClusterInfoB[])
	return Grid(states, fn, gs)
end

function CA.update_global!(::Type{SnakefillB}, gs::SnakefillBGlobal)
	if !isempty(gs.nextlengths)
		m = maximum(gs.nextlengths)
		gs.maxlength = max(gs.maxlength, m)
	end
	gs.nextlengths = []
	gs.tick += 1
end

hasheadandalive(gs::SnakefillBGlobal) = n -> (n.visit == gs.tick - 1) && (n.health > gs.tick)

function chooseheads(::Type{SnakefillB}, heads, gs::SnakefillBGlobal)
	# no head
	isempty(heads) && return heads
	# just one head
	length(heads) == 1 && return heads
	r = roots(gs, heads)

	# find head with max length
	l = map(x -> x.length, heads)
	L = maximum(l)
	h = heads[l .== L]

	# we only have one snake on the board
	# too many heads
	# length(h) > 1 && return nothing
	# the max health one
	j = map(x -> x.health, h)
	J = maximum(j)
	k = h[j .== J]

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

function createCluster!(gs::SnakefillBGlobal)
	cls = gs.clusters
	n = length(cls) + 1
	push!(cls, ClusterInfoB(n, n))
	return n
end

function setroot!(gs::SnakefillBGlobal, a::UInt8, b::UInt8)
	gs.clusters[a].root = b
end

function roots(gs::SnakefillBGlobal, heads::Array{SnakefillB,1})
	return (x -> root(gs, x)).(cluster.(heads))
end

root(gs::SnakefillBGlobal, head::SnakefillB) = root(gs, head.clusterId)
function root(gs::SnakefillBGlobal, n::UInt8)
	n == 0 && return n
	gs.clusters[n].root == n && return n
	r = root(gs, gs.clusters[n].root)
	gs.clusters[n].root = r
	return r
end

# assign values to nf rather than allocating new memory
function CA.step(sf::SnakefillB, n::Array{SnakefillB,1}, gs::SnakefillBGlobal)	
	visit = sf.visit
	food = sf.food
	hl = sf.health
	len = sf.length
	clusterId = sf.clusterId
	if !(isoccupied(sf, gs) || everoccupied(sf))
		heads = n[hasheadandalive(gs).(n)]
		H = chooseheads(SnakefillB, heads, gs)
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
			if food 
				food = false
				hl = SNAKE_MAX_HEALTH + gs.tick
				len = len + 1
				if len > gs.maxlength
					push!(gs.nextlengths, len)
				end
			end
		end
	end

	return SnakefillB(visit, food, hl, len, clusterId)
end


