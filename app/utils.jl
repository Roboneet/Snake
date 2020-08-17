function logger(f, req)
    if DEBUG
        @info req.method, URI(req.target)
    end

    res = f(req)
    if isa(res, HTTP.Response)
        if DEBUG
            @info req.method, URI(req.target), res.status
        end
    else
        @error req.method, URI(req.target), res[:status]
        try
            d = String(copy(req.body))
            @info :data d
        catch e
            println("Cannot show body")
        end

        if DEBUG
            body!(w, String(deepcopy(res[:body])))
        end
    end
    return res
end

function xy(k, rows, columns) 
	v = (rows - k["y"], k["x"] + 1)
    return v
end

function extract(params::Dict)
	gameid = params["game"]["id"]
    board_p = params["board"]
    height = board_p["height"]
    width = board_p["width"]
	food = extract_food(board_p["food"], height, width)
	if haskey(board_p, "hazards")
		hazards = extract_food(board_p["hazards"], height, width)
	else
		hazards = Tuple{Int,Int}[]
	end
    snakes = Snake[]
    me = -1
    for i=1:length(board_p["snakes"])
        u = board_p["snakes"][i]
        if u["id"] === params["you"]["id"]
            me = i
        end
        trail = extract_snake_trail(u["body"], height, width)
		direction = extract_snake_direction(trail)
        push!(snakes, Snake(i, trail, u["health"], true, direction, nothing))
    end
    mode = length(snakes) == 1 ? SINGLE_PLAYER_MODE : MULTI_PLAYER_MODE
    return (state=SType(Config(height, width, mode), food,
        snakes, length(snakes), params["turn"], hazards), me=me, gameid=gameid)
end

function extract_food(f, height, width)
	isempty(f) && return Tuple{Int,Int}[]
    return map(ele -> xy(ele, height, width), f)
end

function extract_snake_trail(f, height, width)
	trail = reverse(collect(map(ele -> xy(ele, height, width), f)))
	return trail
end

function extract_snake_direction(trail)
	(trail[end] === nothing || trail[end - 1] === nothing) &&
		return trail[end - 1] .- trail[end - 2]
	return trail[end] .- trail[end - 1]
end
