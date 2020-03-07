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

if haskey(ENV, "REDIS_URL")
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
