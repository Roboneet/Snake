# include("ca.jl")

# import .CA: Grid, step!, states, step

function step(a::Bool, n, t)
	l = count(n)
	return (l == 3) || (a && l == 2)
end

function update_global!(::Type{Bool}, ::Nothing) end

function GOL(k = Bool[
					  0 1 0 0 0 0
					  0 0 1 0 0 0
					  1 1 1 0 0 0
					  0 0 0 0 0 0
					  0 0 0 0 0 0
					  0 0 0 0 0 0
					  ]
			 )
	legends = (i) -> i ? '▀' : ' '
	grid = Grid(k, (i, j) -> begin
					w = 6
					x = w*(i - 1) + j
					l = [x + 1, 
						 x - 1, 
						 x - w, 
						 x - w - 1, 
						 x - w + 1, 
						 x + w, 
						 x + w + 1, 
						 x + w - 1]
					map(y -> ((y - 1 + 36) % 36) + 1, l)
				end, nothing)
	current() = legends.(states(grid))
	next!() = begin
		CA.step!(grid)
		legends.(states(grid))
	end
	return grid, current, next!
end

