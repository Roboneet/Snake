function firstcall()
    algos = [intersect((Basic,), 4), Grenade, Kettle, Cupcake, Grenade, DKiller]
    env = SnakeEnv((11,11), length(algos))
    s = state(env)
    moves = ntuple(x -> findmove(algos[x], s, x), length(algos))
    step!(env, moves)
end

firstcall()
