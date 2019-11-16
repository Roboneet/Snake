include("Snake.jl")

function main()
	N = 4
	env = SnakeEnv((8, 8), N)
	
	display(env)

	while !done(env)
		s = state(env)
		moves = map(x -> find_move(s, x), 1:N)
		# @show moves
		step!(env, moves)
		display(env)
	end

end

function find_move(s, i)
	snake = s[:snakes][i]
	food = s[:food]
	
	if !snake.alive
		return (0,0)
	end
	
	I = head(snake)
	r, c = s[:height], s[:width]
	M = Inf

	dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
	cls = cells(r, c, s[:snakes], food)

	D = filter(x -> in_bounds((I .+ x)..., r, c) && 
			length(snakes(cls[(I .+ x)...])) == 0, dirs)
	j = length(D) > 0 ? rand(D) : rand(dirs);

	for i in D
		J = I .+ i
		if in_bounds(J..., r, c)
			s = Inf
			for f in food
				s = min(s, sum(abs.(J .- f)))
			end
			println("$(snake.id): $(i) $(s)")
			if s < M
				M = s
				j = i
			end
		end
	end

	return j
end