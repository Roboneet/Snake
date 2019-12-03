struct Cupcake <: AbstractAlgo end


findmoves(algo::Type{Cupcake}, s, N, i) = findmove(algo, s, i)
function findmoves(algo::Type{Cupcake}, s, N)
	return map(i -> findmove(algo, s, i), 1:N)
end

function findmove(algo::Type{Cupcake}, s, i)
	good_moves = astar(s, i)
	return rand(good_moves)
end