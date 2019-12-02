struct Grenade <: AbstractAlgo end

function findmoves(algo::Type{Grenade}, s, N)
	# return map(x -> findmove(s, x), 1:N)
	return assign(s, N, (args...) -> findmove(algo, args...))
end

function findmove(algo::Type{Grenade}, s, i)
	# one problem: it will never moveto the cell that contained another snake's tail in the previous trun
	good_moves = astar(s, i)
	# @show good_moves
	return rand(good_moves)
end