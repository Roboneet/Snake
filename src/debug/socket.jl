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

WSParser(h, w) = WSParser(Config(h, w, MULTI_PLAYER_MODE, nothing))

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
	
	snakes = filter(x -> x["death"] === nothing, d["snakes"])
	snakes = map(1:length(snakes)) do i
        x = snakes[i]
        trail = extract_snake_trail(x["body"], height, width)
		trail = map(p -> (height - p[1] + 1, p[2],), trail)
        direction = extract_snake_direction(trail)
        alive = (x["death"] === nothing)
        Snake(i, trail, x["health"], alive,
         direction, nothing)
	end
	function plist(x)
		food = extract_food(d[x], height, width)
		food = map(p -> (height - p[1] + 1, p[2],), food)
	end
	food = plist("food")
	hazards = plist("hazards")

    SType(w.config,
		food,
        snakes, count(alive.(snakes)),
        d["turn"], hazards)
end
