using Mux
using Mux: URI
using JSON
using HTTP
# using Blink

const DEBUG = false
const DBNAME = :gamestore
const TABLENAME = :games
const USE_DB = false

if DEBUG && !isdefined(Main, :w)
    w = Blink.Window()
end

include("../algo/algo.jl")
include("controller.jl")

using Sockets
if haskey(ENV, "ON_HEROKU")
    println("Starting...")
    serve(sankeserver, ip"0.0.0.0", parse(Int, ENV["PORT"]))
    println("Serving on port $(ENV["PORT"])")
else
    serve(sankeserver, haskey(ENV, "port") ? parse(Int, ENV["port"]) : 8080)
end

include("firstcall.jl")

Base.JLOptions().isinteractive==0 && wait()
