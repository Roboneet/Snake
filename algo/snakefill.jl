# VERSION A
# a cellular automata version of clusterify's bfs with 1 snake
#
#

include("../env/Snake.jl")
include("ca.jl")

const MAX_HEALTH = 10

abstract type AbstractSnakefill end

mutable struct SnakefillA <: AbstractSnakefill
	visit::Int # tick at which this block was visited
	food::Bool # true if block has food
	health::Int # maximum health possible when visiting
	length::Int # maximum length possible when visiting
end

mutable struct SnakefillAGlobal
	tick::Int
	maxlength::Int
	nextlengths::Array{Int,1}
end

function update_global!(::Type::{SnakefillA}, gs::SnakefillAGlobal)
	m = maximum(gs.nextlengths)
	gs.nextlengths = []
	gs.maxlength = max(gs.maxlength, m)
	gs.tick += 1
end

hasheadandalive(gs::SnakefillAGlobal) = n -> (n.visit == gs.tick - 1) && (n.health > 1)

function choose(heads)
	# no head
	isempty(heads) && return nothing

	# just one head
	length(heads) == 1 && return heads[1]

	# find head with max length
	l = map(x -> x.length, heads)
	L = maximum(l)
	h = heads[l .== L]

	# too many heads
	length(h) > 1 && return nothing

	# the one
	return h[1]
end

function step(sf::SnakefillA, n::Array{SnakefillA,1}, gs::SnakefillAGlobal)	
	occupied = sf.visit + gs.maxlength >= sf.tick
	occupied && return copy(sf)

	heads = n[hashead(gs).(n)]
	h = choose(heads)
	h == nothing && return copy(sf)

	next = SnakefillA(gs.tick, false, h.health - 1, h.length)
	!sf.food && return next

	next.health = MAX_HEALTH
	next.length = h.length + 1
	if nf.length > gs.maxlength
		push!(gs.nextlengths, next.length)
	end
	return next
end


