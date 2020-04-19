function firstcall()
    algos = [Grenade, Kettle, Cupcake, Grenade]
    env = SnakeEnv((11,11), length(algos))
    s = state(env)
    moves = ntuple(x -> findmove(algos[x], s, x), length(algos))
    step!(env, moves)
end

firstcall()
