function firstcall()
	algos = [Grenade, sls(2)]
    env = SnakeEnv((11,11), length(algos))
    s = state(env)
    moves = ntuple(x -> findmove(algos[x], s, x), length(algos))
    step!(env, moves)
end

firstcall()
