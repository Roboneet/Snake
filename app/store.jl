module Persistence

using JSON
using Redis

abstract type AbstractStore end

# connection info, not the socket
struct Store <: AbstractStore
    host
    port
    password
    db
end

connect(s::Store) = RedisConnection(
    ;host=s.host, port=s.port,
    password=s.password, db=s.db)

key(s::Store, gameid::String, algo, state, me::Int, move) =
    key(s::Store, gameid, algo, state)
key(s::Store, gameid::String, algo, state, me::Int) =
    key(s::Store, gameid, algo, state)
key(s::Store, gameid::String, algo, state) = "$(gameid):$(state.turn):$(algo)"

value(s::Store, gameid::String, algo, state, me::Int, move) =
    JSON.json((state=state, me=me, move=move,))
value(s::Store, gameid::String, algo, state, me::Int) =
    JSON.json((state=state, me=me,))

function __keep__(k::T, args...) where T <: AbstractStore
    @async begin
        println("connecting...")
        conn = connect(k)
        println("writing...")
        set(conn, key(k, args...), value(k, args...))
        println("written.")
        disconnect(conn)
        println("disconnected.")
    end
end

end

const store = Persistence.Store(REDIS_HOST, REDIS_PORT, REDIS_PASSWORD, REDIS_DB)

keep(args...) = Persistence.__keep__(store, args...)
