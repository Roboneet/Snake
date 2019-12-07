struct Grenade <: AbstractAlgo end


findmoves(algo, st, N, i) = findmove(algo, st, i, [assign(st, N)[i]])
function findmoves(algo::Type{Grenade}, s, N)
	targets = assign(s, N)
	return map(x -> findmove(algo, s, x, [targets[x]]), 1:N)
end

function reachable(food, dir, clusters)
	return filter(f -> any(map(d -> clusters[d...] == clusters[f...], dir)), food)
end

function findmove(algo::Type{Grenade}, s, i, t)
	snake = s[:snakes][i]
	!alive(snake) && return (0, 0)
	
	food = collect(s[:food])
	I = head(snake)
	r, c = s[:height], s[:width]

	cls = cells(r, c, s[:snakes], food)
	clusters, cdict = floodfill(cls)

	
	dir = flow(choose(x -> in_bounds((I .+ x)..., s[:height], s[:width])),                   
		choose(x -> freecell(cls[(I .+ x)...], cls, s[:snakes])),            
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])))(DIRECTIONS)

	if health(snake) < SNAKE_MAX_HEALTH/3
		r = reachable(food, map(x -> I .+ x, dir), clusters)
		if !isempty(r)
			t = r
		end
	end

	hasfood = !(length(t) == 1 && t[1] == nothing)

	dir = (flow(through(hasfood, biggercluster(I, clusters, cdict)),
		choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s[:snakes]))) # may return 0 elements 
	)(dir)


	good_moves = hasfood ? astar(cls, I, t, dir) : astar(cls, I, [tail(snake)], dir)
	good_moves = hasfood ? good_moves : biggercluster(I, clusters, cdict)(good_moves)
	return rand(good_moves)
end