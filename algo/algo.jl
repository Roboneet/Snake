abstract type AbstractAlgo end

include("utils.jl")
include("Grenade.jl")
include("Cupcake.jl")
include("Kettle.jl")

play(n=4) = play(Grenade, (8, 8), n)