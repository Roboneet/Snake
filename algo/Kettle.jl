struct Kettle <: SafeGreedy end

pipe(algo::Type{Kettle}, s::SType, i::Int) = __pipe__(algo, s, i, tailchase=false)

function clusterify(algo::Type{Kettle}, cls, snks)
	reachableclusters(cls, snks)
end
