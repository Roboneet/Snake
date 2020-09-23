# 2D Cellular automata
# NOT USED ANYWHERE RIGHT NOW
#
# Initial system state
# synchronous steps

# initCA(cell state matrix, neighbours function)
# stepCA(cell, neighbours)

# system -> graph of cells
# cell -> contains cell state, and meta info (neighbours)

module CA
mutable struct Cell{T}
	state::T
	next::T
	neighbours::Array{Cell{T},1}
end
function Base.show(io::IO, c::Cell)
	print(io, "Cell(")
	Base.show(io, state(c))
	print(io, ", $(length(c.neighbours)))")
end

mutable struct Grid{T,K}
	cells::Array{Cell{T},2}
	global_state::K
	seeds::Union{Nothing,Array{Cell{T},1}}
	function Grid(states, f, global_state) 
		T = eltype(states)
		cells = similar(states, Cell{T})
		for i in eachindex(states) 
			cells[i] = Cell(states[i], states[i], Cell{T}[])
		end
		r, cl = size(cells)
		for j=1:cl, i=1:r
			cells[i, j].neighbours = neighbours(f, cells, i, j)
		end
		new{T,typeof(global_state)}(cells, global_state, nothing)
	end
end

function update_global!(args...)
	error("method not implemented")
end

function step(args...)
	error("method not implemented")
end

cells(g::Grid) = g.cells
seeds(g::Grid) = g.seeds

function may_change_state(g::Grid)
	seeds(g) == nothing && return cells(g)
	unique(vcat(neighbours.(seeds(g))...))
end

function populatenext!(g::Grid, m)
	for c in m
		n = state.(c.neighbours)
		c.next = step(state(c), n, g.global_state)
	end
end

function update_states!(g::Grid{T,K}, m) where {T,K}
	seeds = Cell{T}[]
	for c in m
		if c.state != c.next
			push!(seeds, c)
			c.state = c.next
		end
	end
	g.seeds = seeds
end

function step!(g::Grid{T,K}) where {T,K}
	update_global!(T, g.global_state)
	m = may_change_state(g)
	populatenext!(g, m)
	update_states!(g, m)
	return g
end

state(c::Cell) = c.state

function states(g::Grid{T,K}) where {T,K}
	states(g, similar(g.cells, T))
end

function states(g::Grid, m)
	for i in eachindex(m)
		m[i] = g.cells[i].state
	end
	return m
end

function neighbours(f, cells, i, j)
	return cells[f(i, j)]
end

neighbours(cell::Cell{T}) where T  = cell.neighbours

end

