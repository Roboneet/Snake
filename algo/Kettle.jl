struct Kettle <: SafeGreedy end

findmove(algo::Type{Kettle}, s, i) = __findmove__(algo, s, i, tailchase=false)

function findmoves(algo::Type{Kettle}, s)
	N = length(s.snakes)
	return map(x -> findmove(algo, s, x, tailchase=false), 1:N)
end

function clusterify(algo::Type{Kettle}, cls, snks)
	reachableclusters(cls, snks)
end