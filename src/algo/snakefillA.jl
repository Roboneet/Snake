# VERSION A
# a cellular automata version of clusterify's bfs with 1 snake
#

using Colors

include("./ca.jl")
import .CA: Grid, step!, states, step, update_global!

abstract type AbstractSnakefill end

struct SnakefillA <: AbstractSnakefill
	visit::Int # tick at which this block was visited
	food::Bool # true if block has food
	health::Int # maximum health possible when visiting
	length::Int # maximum length possible when visiting
end
SnakefillA(l) = SnakefillA(l, false, 0, 0)
visit(sf::SnakefillA) = sf.visit
hasfood(sf::SnakefillA) = sf.food

mutable struct SnakefillAGlobal
	tick::Int
	maxlength::Int
	nextlengths::Array{Int,1}
end

function Base.show(io::IO, c::Grid{SnakefillA, SnakefillAGlobal})
	st = states(c)
	v = visit.(st)
	m = v .- (-c.global_state.maxlength + c.global_state.tick)
	fint = x -> floor(Int, x)
	color = x -> fint.((x.r*255, x.g*255, x.b*255))
	color_palette = range(colorant"#a26fbb", colorant"#17847f", length=max(maximum(m), 3))
	println(io, c.global_state.maxlength)
	print(io, colorarray(m, Tuple.(findall(hasfood.(st))), color.(color_palette)))
end

function showprop(c::Grid{SnakefillA}, f, l=nothing)
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


function createCA(::Type{SnakefillA}, st::SType)
	h, w = height(st), width(st)
	states = Array{SnakefillA,2}(undef, h, w)
	snake = st.snakes[1]
	tr = trail(snake)
	l = -length(tr)
	for j=1:w, i=1:h
		states[i, j] = SnakefillA(l)
	end
	for i=1:length(tr)
		visit = i - length(tr)
		hl = health(snake)
		len = length(tr)
		states[tr[i]...] = SnakefillA(visit, false, hl, len)
	end
	food = st.food
	for i=1:length(food)
		states[food[i]...] = SnakefillA(l, true, 0, 0)
	end
	fn = (i, j) -> begin
		n = neighbours((i, j), h, w)
		map(x -> h*(x[2] - 1) + x[1], n)
	end
	gs = SnakefillAGlobal(0, length(snake), Int[])
	return Grid(states, fn, gs)
end

function CA.update_global!(::Type{SnakefillA}, gs::SnakefillAGlobal)
	if !isempty(gs.nextlengths)
		m = maximum(gs.nextlengths)
		gs.maxlength = max(gs.maxlength, m)
	end
	gs.nextlengths = []
	gs.tick += 1
end

hasheadandalive(gs::SnakefillAGlobal) = n -> (n.visit == gs.tick - 1) && (n.health > gs.tick)

function chooseheads(::Type{SnakefillA}, heads)
	# no head
	isempty(heads) && return heads
	# just one head
	length(heads) == 1 && return heads
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
	# the one
	return k
end

function isoccupied(sf, gs)
	return sf.visit + gs.maxlength > gs.tick
end

function everoccupied(sf)
	return sf.visit > 0
end

# assign values to nf rather than allocating new memory
function CA.step(sf::SnakefillA, n::Array{SnakefillA,1}, gs::SnakefillAGlobal)	
	visit = sf.visit
	food = sf.food
	hl = sf.health
	len = sf.length

	if !(isoccupied(sf, gs) || everoccupied(sf))
		heads = n[hasheadandalive(gs).(n)]
		H = chooseheads(SnakefillA, heads)
		if !isempty(H)
			h = H[1] # just choose the first one
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

	return SnakefillA(visit, food, hl, len)
end


