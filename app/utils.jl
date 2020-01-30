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

xy(k) = (k["y"] + 1,k["x"] + 1)
function extract(params::Dict)
	gameid = params["game"]["id"]
    board_p = params["board"]
    height = board_p["height"]
    width = board_p["width"]
	if isempty(board_p["food"])
		food = Tuple{Int,Int}[]
	else
    	food = xy.(board_p["food"])
	end
    snakes = Snake[]
    me = 1
    for i=1:length(board_p["snakes"])
        u = board_p["snakes"][i]
        if u["id"] === params["you"]["id"]
            me = i
        end
        trail = reverse(collect(xy.(u["body"])))
        trail = map(p -> in_bounds(p..., height, width) ?
                    p : nothing, trail)
        if length(trail) > 1
            direction = trail[end] .- trail[end - 1]
        else
            direction = nothing
        end
        push!(snakes, Snake(i, trail, u["health"], true, direction, nothing))
    end
    return (state=SType(Config(height, width, MULTI_PLAYER_MODE), food,
        snakes, length(snakes), params["turn"]), me=me, gameid=gameid)
end
