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

xy(k, rows, columns) = (rows - k["y"], columns - k["x"])

function extract(params::Dict)
	gameid = params["game"]["id"]
    board_p = params["board"]
    height = board_p["height"]
    width = board_p["width"]
	food = extract_food(board_p["food"], height, width)
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
    return (state=SType(Config(height, width, MULTI_PLAYER_MODE), food,
        snakes, length(snakes), params["turn"]), me=me, gameid=gameid)
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
	(trail[end] == nothing || trail[end - 1] == nothing) &&
		return trail[end - 1] .- trail[end - 2]
	return trail[end] .- trail[end - 1]
end

# Example Usage

#	str = """
#	       {"Turn":1,"Food":[{"X":4,"Y":2},{"X":7,"Y":8},{"X":4,"Y":5}],"Snakes":[{"ID":"gs_T66wftFQjpShvRYmVBSHjY7H","Name":"anna kondo","URL":"","Body":[{"X":1,"Y":4},{"X":1,"Y":5},{"X":1,"Y":5},{"X":1,"Y":5}],"Health":100,"Death":null,"Color":"#00FF00","HeadType":"smile","TailType":"small-rattle","Latency":"341","Shout":"I am a python snake!","Team":""},{"ID":"gs_FBvMc7jBwM48wdH8hxDcm7w3","Name":"Polka Dotted Goggles","URL":"","Body":[{"X":0,"Y":9},{"X":1,"Y":9},{"X":1,"Y":9}],"Health":99,"Death":null,"Color":"#8752ef","HeadType":"","TailType":"","Latency":"334","Shout":"","Team":""},{"ID":"gs_JyGrrkbghRj3r7HqYkbrdmFX","Name":"unapersona","URL":"","Body":[{"X":9,"Y":4},{"X":9,"Y":5},{"X":9,"Y":5}],"Health":99,"Death":null,"Color":"#16a085","HeadType":"pixel","TailType":"pixel","Latency":"465","Shout":"","Team":""},{"ID":"gs_GwgD7qvRG8VQ7hMc9xvVjvKT","Name":"Independent","URL":"","Body":[{"X":9,"Y":8},{"X":9,"Y":9},{"X":9,"Y":9}],"Health":99,"Death":null,"Color":"#00FF00","HeadType":"","TailType":"","Latency":"294","Shout":"","Team":""}]}
#	       """
#	WSParser(11, 11)(str) |> x -> Frame(x, nothing)
