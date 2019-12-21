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
algoDict["cupcake"] = Cupcake
algoDict["kettle"] = Kettle

function whichalgo(req)
    if haskey(req, :params)
        name = req[:params][:s]
        if !haskey(algoDict, name)
            name = "default"
        end
    end

    return algoDict[name]
end

function move(req, wa=whichalgo)
    d = JSON.parse(String(copy(req[:data])))
    st, me = extract(d)
    algo = wa(req)
    move = findmove(algo, st, me)
    T = Dict((1, 0)=>"down", (-1, 0)=>"up", (0, 1)=>"right", (0, -1)=>"left")
    move = T[move]
    return JSON.json((move=move,))
end

test_lightspace(req) = move(req, (r) -> lightspace(parse(Int, r[:params][:n])))

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
        if haskey(req, :data)
            @info :data req[:data]
        end
        if DEBUG
            body!(w, String(deepcopy(res[:body])))
        end
    end
    return res
end

function foo(req)
    st, me = extract(JSON.parse(String(req[:data])))
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
   page("/test/lightspace/:n/move", test_lightspace),
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
