struct Grenade <: AbstractAlgo end


findmoves(algo, st, N, i) = findmove(algo, st, i, assign(st, N)[i])
function findmoves(algo::Type{Grenade}, s, N)
	targets = assign(s, N)
	return map(x -> findmove(algo, s, x, target[i]), 1:N)
end

function findmove(algo::Type{Grenade}, s, i, t)
	snake = s[:snakes][i]
	food = collect(s[:food])
	I = head(snake)
	r, c = s[:height], s[:width]

	cls = cells(r, c, s[:snakes], food)

	food = t != nothing 

	clusters, cdict = floodfill(cls)
	dir = (flow(choose(x -> in_bounds((I .+ x)..., s[:height], s[:width])),                   
		choose(x -> freecell(cls[(I .+ x)...], cls, s[:snakes])),            
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])),  
		through(food, biggercluster(I, clusters, cdict)),
		choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s[:snakes]))) # may return 0 elements 
	)(DIRECTIONS)


	good_moves = food ? astar(cls, I, [t], dir) : astar(cls, I, [tail(snake)], dir)
	return rand(good_moves)
end