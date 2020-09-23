include("../env/SnakePit.jl") 
# import .SnakePit

# import .SnakePit: SType, Game, Snake, Cell, Board, done, step!, reset!
# import .SnakePit: alive, head, cells, height, width, in_bounds, snakes, id, health
# import .SnakePit: SNAKE_COLORS, hassnake, mode, SINGLE_PLAYER_MODE, MULTI_PLAYER_MODE
# import .SnakePit: indices, gamestate, copystate, neighbours, tail, head, showcells
# import .SnakePit: SNAKE_COLORS, DIRECTIONS, SNAKE_MAX_HEALTH
# import .SnakePit: SINGLE_PLAYER_MODE, MULTI_PLAYER_MODE

abstract type AbstractAlgo end

include("../utils/frames.jl")

include("Basic.jl")
include("clustering.jl")
include("partialexplore.jl")
include("utils.jl")
include("Lookahead.jl")
include("Value.jl")
include("Grenade.jl")
include("Cupcake.jl")
include("Kettle.jl")
include("Minimax.jl")
include("AvgMax.jl")
include("Hybrid.jl")
