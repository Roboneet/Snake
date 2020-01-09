struct AvgMax{T <: AbstractTorch} <: AbstractAlgo end

torch(l::Type{AvgMax{T}}) where T = T()

function avgmaxreduce(fr::Frame, i::Int, f=statevalue)
	isempty(fr.children) && return f(fr, i), []
	# display(fr.children)
	# display(ch)

	q = Dict{Tuple{Int,Int},Float64}()
	a = Dict{Tuple{Int,Int},Tuple{Int,Float64}}()
	for (k, v) in fr.children
		# @show k
		# @show k[i]
		u, v = avgmaxreduce(v, i, f)
		if haskey(q, k[i])
			x, y = a[k[i]]
			a[k[i]] = (x + 1, y + u)
			q[k[i]] = a[k[i]][2]/a[k[i]][1]
		else
			a[k[i]] = (1, u)
			q[k[i]] = u
		end
	end

	maxpairs(q)
end

function pipe(algo::Type{AvgMax{M}}, s::SType, i::Int) where M
	return DIR -> begin
		K = spacelook(algo, s, i; f=avgmaxreduce)
		f = flow(closestfood(s, i))
		m = f(K)
	end
end

Base.intersect(::Type{AvgMax}, x, N::Int) = AvgMax{Intersect{Tuple{x...},N}}
