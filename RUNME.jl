# run `julia -i RUNME.jl` from project root

using Pkg
Pkg.activate(".")

include("debug/playground.jl")

fr = play([sls(2), Kettle, Kettle, Killer{1}], SnakeEnv((11, 11), 4))
