abstract type SafeGreedy <: AbstractAlgo end

struct Grenade <: SafeGreedy end


pipe(algo::Type{T}, st::SType, i::Int) where T <: SafeGreedy =
 __pipe__(algo, st, i, t=[assign(st)[i]])
function findmoves(algo::Type{Grenade}, s::SType)
	N = length(s.snakes)
	targets = assign(s)
	return map(x -> findmove(algo, s, x, t=[targets[x]]), 1:N)
end

function reachable(food::T, dir::T, clusters) where T <: AbstractArray{Tuple{Int,Int},1}
	return filter(f -> any(map(d -> clusters[d...] == clusters[f...], dir)), food)
end

function clusterify(algo::Type{T}, cls, snks) where T <: SafeGreedy
	floodfill(cls)
end


function __pipe__(algo::Type{T}, s::SType, i::Int; t=s.food, tailchase=true) where T <: SafeGreedy
	return DIR -> begin
		snake = s.snakes[i]
		!alive(snake) && return (0, 0)

		food = s.food
		I = head(snake)
		r, c = height(s), width(s)
		cls = cells(r, c, s.snakes, food)
		clusters, cdict = clusterify(algo, cls, s.snakes)

		dir = flow(canmove(s, i, I, cls)...,
			choose(x -> !nearbigsnake(cls[(I .+ x)...], snake, cls, s.snakes)))(DIR)

		if health(snake) > 10 || isempty(food)
			t = [nothing]
		end

		hasfood = !(length(t) == 1 && t[1] === nothing)
		dir = (flow(through(hasfood || !tailchase, biggercluster(I, clusters, cdict)),
			choose(x -> nearsmallsnake(cls[(I .+ x)...], snake, cls, s.snakes))) # may return 0 elements
		)(dir)

		good_moves = hasfood ? astar(cls, I, t, dir) : tailchase ? astar(cls, I, [tail(snake)], dir) : dir
		good_moves = hasfood ? good_moves : biggercluster(I, clusters, cdict)(good_moves)
		return good_moves
	end
end
