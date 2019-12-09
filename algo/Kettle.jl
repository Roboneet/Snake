struct Kettle <: SafeGreedy end

findmoves(algo::Type{Kettle}, s, N, i) = findmove(algo, s, i, tailchase=false)

function findmoves(algo::Type{Kettle}, s, N)
	return map(x -> findmove(algo, s, x, tailchase=false), 1:N)
end

function clusterify(algo::Type{Kettle}, cls, snks)
	d = map(x -> distancematrix(cls, head(x)), snks)
	M, N = size(cls)
	partitions = partition(snks, d)
	flooded, fdict = floodfill(cls)

	clusters = Array{Any, 2}(undef, (M, N))

	u = Dict()

	cnt = 1
	for i=1:M, j=1:N
		if hassnake(cls[i, j])
			clusters[i, j] = 0
		else
			p = partitions[i, j]
			if !haskey(u, p)
				u[p] = Dict()
			end
			f = flooded[i, j]
			if !haskey(u[p], f)
				u[p][f] = cnt
				cnt += 1
			end
			clusters[i, j] = u[p][f]
		end
	end

	# @show clusters
	cdict = Dict()
	
	for i=1:M, j=1:N
		c = clusters[i, j]
		if !haskey(cdict, c)
			cdict[c] = 0
		end

		cdict[c] += 1
	end
	return clusters, cdict
end