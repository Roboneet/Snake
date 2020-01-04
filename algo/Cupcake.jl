struct Cupcake <: AbstractAlgo end

function notnearestsnake(snake, cls, snakeslist)
	bigsnakes = filter(x -> id(x) != id(snake), filter(alive, snakeslist))
	length(bigsnakes) == 0 && return identity

	return y -> begin
		dist = ȳ -> map(x ->
			sum(head(x) .- ȳ),
		bigsnakes)
		score = ȳ -> 1/minimum(dist(ȳ))

		s = map(score, y)
		r = minimum(s)
		return map(x -> x[1], filter(x -> x[2] == r, collect(zip(y, s))))
	end
end



function pipe(algo::Type{Cupcake}, s, i)
	return DIR -> begin
			snake = s[:snakes][i]
			!alive(snake) && return (0, 0)

			food = collect(s[:food])
			I = head(snake)
			cls = cells(s)

			clusters, cdict = floodfill(cls)
			dir = (flow(canmove(s, i, I, cls)...,
				choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])),
				biggercluster(I, clusters, cdict)
			))(DIRECTIONS)

			if health(snake) > SNAKE_MAX_HEALTH*0.95
				# not food
				p = flow(
					notnearestsnake(snake, cls, s[:snakes]),
					choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s[:snakes])))

				good_moves = astar(cls, I, [tail(snake)], p(dir))
			else
				good_moves = astar(cls, I, collect(s[:food]), dir)
			end
		return good_moves
	end
end
