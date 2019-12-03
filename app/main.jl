using Mux
using Mux: URI
using JSON
using HTTP
# using Blink

include("../algo/algo.jl")

DEBUG = false

if DEBUG && !isdefined(Main, :w)
    w = Blink.Window()
end

algoDict = Dict()
algoDict["default"] = Grenade
algoDict["grenade"] = Grenade

function whichalgo(req)
    if !haskey(req, :params)
        return algoDict["default"]
    end
    return algoDict[req[:params][:s]]
end

function move(req)
    d = JSON.parse(deepcopy(String(req[:data])))
    st = state(d)
    algo = whichalgo(req)
    move = findmoves(algo, st, length(st[:snakes]))[st[:me]]
    T = Dict((1, 0)=>"down", (-1, 0)=>"up", (0, 1)=>"right", (0, -1)=>"left")
    move = T[move]
    return JSON.json((move=move,))
end

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
        if DEBUG
            body!(w, String(deepcopy(res[:body])))
        end
    end
    return res
end

function foo(req)
    st = state(JSON.parse(String(deepcopy(req[:data]))))
    io = IOBuffer()
    println(io, st[:turn])
    showcells(io, st)
    println(String(take!(io)))
    return "ok"
end

@app sankeserver = ( 
   logger,
   Mux.defaults,
   page("/", respond("<h1>bla ble blue..... I'm fine, thanks :)</h1>")),
   page("/:s/start", respond("{color:#f00}")),
   page("/:s/move", move),
   page("/:s/ping", respond("ok")),
   page("/:s/end", foo), 
   Mux.notfound()) 


using Sockets
if haskey(ENV, "ON_HEROKU")
    println("Starting...")
    serve(sankeserver, ip"0.0.0.0", parse(Int, ENV["PORT"]))
    println("Serving on port $(ENV["PORT"])")
else
    serve(sankeserver, haskey(ENV, "port") ? parse(Int, ENV["port"]) : 8080)
end

Base.JLOptions().isinteractive==0 && wait()
