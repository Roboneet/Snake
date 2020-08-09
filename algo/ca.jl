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
	neighbours
end
Base.show(io::IO, c::Cell) = Base.show(io, state(c))

mutable struct Grid{T}
	cells
	tick 
	function Grid(states, f) 
		cells = similar(states, Cell)
		for i in eachindex(states) 
			cells[i] = Cell(states[i], states[i], nothing)
		end
		for i in eachindex(cells)
			cells[i].neighbours = neighbours(f, cells, i)
		end
		new{eltype(states)}(cells, 0)
	end

end

function step(args...)
	error("method not implemented")
end
function step!(g::Grid)
	c = g.cells
	g.tick += 1
	for i in eachindex(c)
		n = state.(c[i].neighbours)
		c[i].next = step(state(c[i]), n, g.tick)
	end
	for i in eachindex(c)
		c[i].state = c[i].next
	end
end

state(c::Cell) = c.state

function states(g::Grid{T}) where T
	states(g, similar(g.cells, T))
end

function states(g::Grid, m)
	for i in eachindex(m)
		m[i] = g.cells[i].state
	end
	return m
end

function neighbours(f, cells, i)
	return cells[f(i)]
end

end

