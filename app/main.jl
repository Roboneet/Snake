using Mux
using Mux: URI
using JSON
using HTTP
using Sockets
# using Blink

const DEBUG = false
if DEBUG && !isdefined(Main, :w)
    w = Blink.Window()
end

const USE_REDIS = false
const IS_PROD = haskey(ENV, "ON_HEROKU")

include("../algo/algo.jl")
using .SnakePit: state

include("firstcall.jl")
include("controller.jl")

function startServer()
	if IS_PROD 
		port = parse(Int, ENV["PORT"])
		ipaddr = ip"0.0.0.0"
		println("Starting...")
		serve(sankeserver, ipaddr, port; reuseaddr=true)
		println("Serving on port $(ENV["PORT"])")
	else
		serve(sankeserver, haskey(ENV, "port") ? parse(Int, ENV["port"]) : 8080)
		println("server started")
	end
end

startServer()

Base.JLOptions().isinteractive==0 && wait()
