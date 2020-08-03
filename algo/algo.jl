include("../env/Snake.jl") 
using .SnakePit

using .SnakePit: alive, head, cells, height, width, in_bounds, snakes, id, health
using .SnakePit: SNAKE_COLORS, hassnake, mode, SINGLE_PLAYER_MODE, MULTI_PLAYER_MODE
using .SnakePit: indices, gamestate

abstract type AbstractAlgo end

include("../utils/frames.jl")

include("clustering.jl")
include("partialexplore.jl")
include("utils.jl")
include("Lookahead.jl")
include("Value.jl")
include("Basic.jl")
include("Grenade.jl")
include("Cupcake.jl")
include("Kettle.jl")
include("Minimax.jl")
include("AvgMax.jl")
include("Hybrid.jl")
