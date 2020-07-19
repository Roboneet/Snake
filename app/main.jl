using Pkg
Pkg.activate(".")
Pkg.status()
Pkg.instantiate()

using Mux
using Mux: URI
using JSON
using HTTP
# using Blink

const DEBUG = false

if DEBUG && !isdefined(Main, :w)
    w = Blink.Window()
end

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
REDIS_PASSWORD=""
REDIS_DB=0
USE_REDIS=false
IS_PROD=haskey(ENV, "ON_HEROKU")


if USE_REDIS && haskey(ENV, "REDIS_URL")
    url = ENV["REDIS_URL"]
    # redis://[:password@]host:port[/db]
    c = match(r"^redis://(?:(?:.*):(.*)@)?(.*):(\d*)(?:/(\d*))?", url)
    REDIS_HOST = c[2]
    REDIS_PORT = parse(Int, c[3])
    if c[1] !== nothing
        REDIS_PASSWORD = c[1]
    end

    if c[4] !== nothing
        REDIS_DB = c[4]
    end
end

include("../algo/algo.jl")
include("firstcall.jl")
include("controller.jl")


using Sockets
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
