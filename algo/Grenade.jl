struct Grenade <: AbstractAlgo end


findmoves(algo, st, N, i) = findmoves(algo, st, N)[i]
function findmoves(algo::Type{Grenade}, s, N)
	return assign(s, N, (args...) -> findmove(algo, args...))
end

function findmove(algo::Type{Grenade}, s, i)
	good_moves = astar(s, i)
	return rand(good_moves)
end