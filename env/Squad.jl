# special rules and datatypes for squad mode

struct SquadConfig
	squads::Array{Int,1} # squad of snake = squads[snakeid]
end

function squadenv(size::Tuple{Int,Int}, n::Int, squads::Array{Int,1})
	SnakeEnv(Game(size, n; special=SquadConfig(squads)))
end

function rules(sq::SquadConfig)
	return [
			kill_if_collided_with_wall, 
			decrease_health_by_one,
			decrease_health_in_hazard_zone,
			kill_if_starved,
			kill_if_friend_died(sq),
			eat_if_possible_and_feed_friends(sq),
			kill_if_bit_itself,
			kill_if_bit_another_snake_not_friend(sq),
			kill_if_head_collision,
			kill_if_friend_died(sq),
	]
end

indices(x::BitArray{1}) = (1:length(x))[x]
friends(sq::SquadConfig, i) = indices(sq.squads .== sq.squads[i])
friends(board::Board, snake::Snake, sq::SquadConfig) =
board.snakes[friends(sq, id(snake))]

function eat_if_possible_and_feed_friends(sq::SquadConfig)
	return (b::Board, s::Snake) -> begin
		if caneat(b, s)
			gulp = (s) -> eat!(b, s)
			eat!(b, s)
			# make friends eat
			gulp.(friends(b, s, sq))
		end
	end
end

function kill_if_bit_another_snake_not_friend(sq::SquadConfig)
	return (board::Board, s::Snake) -> begin
	@inbounds cell = board.cells[head(s)...]
	peers = othersnakes_at_head(board, s)
	m = filter(x -> hassnakebody(cell, x), peers)
	f = friends(board, s, sq)
	# m is not empty and m has an element not inside f
	if !isempty(m) && any(map(x -> !(x in f), m))
		# tried to bite another snake
		kill!(board, s, :BIT_ANOTHER_SNAKE)
	end
end
end

function kill_if_friend_died(sq::SquadConfig)
	return (b::Board, s::Snake) -> begin
		f = friends(b, s, sq)
		if !all(alive.(f))
			kill!(b, s, :FRIEND_DIED)
		end
	end
end


