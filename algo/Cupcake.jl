struct Cupcake <: AbstractAlgo end


findmoves(algo::Type{Cupcake}, s, N, i) = findmove(algo, s, i)
function findmoves(algo::Type{Cupcake}, s, N)
	return map(i -> findmove(algo, s, i), 1:N)
end

function findmove(algo::Type{Cupcake}, s, i)
	snake = s[:snakes][i]
	!alive(snake) && return (0, 0)

	food = collect(s[:food])
	I = head(snake)
	cls = cells(s)

	dir = directionpipe(s, i, cls, I)
	if health(snake) > SNAKE_MAX_HEALTH*0.75 && (rand() < 0.85)
		good_moves = astar(cls, I, [tail(snake)], dir)
	else
		good_moves = astar(cls, I, collect(s[:food]), dir)
	end
	return rand(good_moves)
end