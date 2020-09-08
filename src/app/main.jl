using Mux
using Mux: URI
using JSON
using HTTP
using Sockets
# using Blink
using Colors

const DEBUG = false
if DEBUG && !isdefined(Main, :w)
    w = Blink.Window()
end

include("../algo/algo.jl")
# import .SnakePit: state, SnakeEnv, Config

include("controller.jl")

function startServer()
	IS_PROD = haskey(ENV, "ON_HEROKU")
	if IS_PROD 
		port = parse(Int, ENV["PORT"])
		ipaddr = ip"0.0.0.0"
		println("Starting...")
		serve(snakeserver, ipaddr, port; reuseaddr=true)
		println("Serving on port $(ENV["PORT"])")
	else
		serve(snakeserver, haskey(ENV, "port") ? parse(Int, ENV["port"]) : 8080)
		println("server started")
	end
end

