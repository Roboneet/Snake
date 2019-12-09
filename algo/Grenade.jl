abstract type SafeGreedy <: AbstractAlgo end

struct Grenade <: SafeGreedy end


findmoves(algo::Type{T}, st, N, i) where T <: SafeGreedy =
 findmove(algo, st, i, t=[assign(st, N)[i]])
function findmoves(algo::Type{T}, s, N) where T <: SafeGreedy
	targets = assign(s, N)
	return map(x -> findmove(algo, s, x, t=[targets[x]]), 1:N)
end

function reachable(food, dir, clusters)
	return filter(f -> any(map(d -> clusters[d...] == clusters[f...], dir)), food)
end

function clusterify(algo::Type{T}, cls, snks) where T <: SafeGreedy
	floodfill(cls)
end

function findmove(algo::Type{T}, s, i; t=collect(s.food), tailchase=true) where T <: SafeGreedy
	snake = s[:snakes][i]
	!alive(snake) && return (0, 0)
	
	food = collect(s[:food])
	I = head(snake)
	r, c = s[:height], s[:width]

	cls = cells(r, c, s[:snakes], food)
	clusters, cdict = clusterify(algo, cls, s[:snakes])

	
	dir = flow(choose(x -> in_bounds((I .+ x)..., s[:height], s[:width])),                   
		choose(x -> freecell(cls[(I .+ x)...], cls, s[:snakes])),            
		choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s[:snakes])))(DIRECTIONS)
	# @show :1, dir

	food = reachable(food, map(x -> I .+ x, dir), clusters)

	if health(snake) < SNAKE_MAX_HEALTH/3
		
		if !isempty(food)
			t = food
		end
	end

	if isempty(food)
		t = [nothing]
	end

	hasfood = !(length(t) == 1 && t[1] == nothing)

	dir = (flow(through(hasfood || !tailchase, biggercluster(I, clusters, cdict)),
		choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s[:snakes]))) # may return 0 elements 
	)(dir)

	# @show :2, dir

	good_moves = hasfood ? astar(cls, I, t, dir) : tailchase ? astar(cls, I, [tail(snake)], dir) : dir
	# @show :1, good_moves
	good_moves = hasfood ? good_moves : biggercluster(I, clusters, cdict)(good_moves)
	# @show :2, good_moves
	return rand(good_moves)
end