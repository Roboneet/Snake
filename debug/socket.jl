# parse the board state from
# messages send from battlesnake engine to client

# (checkout WS panel on Networks tab to find
# and filter these messages)

using JSON
include("../env/Snake.jl")
include("../app/utils.jl")

struct WSParser
    config::Config
end

WSParser(h, w) = WSParser(Config(h, w, MULTI_PLAYER_MODE))

smallkeys(x) = x
smallkeys(x::AbstractArray) = smallkeys.(x)
function smallkeys(d::Dict)
    Dict((map(collect(d)) do x
        lowercase(x[1]) => smallkeys(x[2])
    end)...)
end


(w::WSParser)(str::String) = w(smallkeys(JSON.parse(str)))
function (w::WSParser)(d::Dict)
    c = w.config
    height, width = c.height, c.width
    snakes = map(1:length(d["snakes"])) do i
        x = d["snakes"][i]
        trail = extract_snake_trail(x["body"], height, width)
        direction = extract_snake_direction(trail)
        alive = (x["death"] == nothing)
        Snake(i, trail, x["health"], alive,
         direction, nothing)
    end
    SType(w.config,
        extract_food(d["food"]),
        snakes, count(alive.(snakes)),
        d["turn"])
end