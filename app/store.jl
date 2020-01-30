using LibPQ

abstract type AbstractStore end

struct Persistence
    conn
    stores
end

Persistence(name) = Persistence(
    LibPQ.Connection("dbname=$(string(name))"),
    Dict())
stores(p::Persistence) = p.stores

struct TempStore <: AbstractStore
    id
    algo
    data
end
TempStore(id, algo) = TempStore(id, algo, Dict())

function schema(t::TempStore)
    return "(
        id varchar(20) NOT NULL,
        algo varchar(20),
        data varchar,
        PRIMARY KEY (id)
    )"
end

# compress and store
# struct GameStore <: AbstractStore
#     id
#     algo
#     config::Config
#     scenes::Vector{Union{Missing,SceneStore}}
# end
#
# struct SceneStore
#     snakes
#     food
#     me
#     move
# end

const DB = Persistence(USE_DB ? DBNAME : nothing, Dict())

function store(id, algo, st::SType, me, move; db=DB)
    stores_ = stores(db)
    # TODO: use LRU
    store = get!(stores_, id, TempStore(id, algo))
    store.data[turn(st)] = (st, me, move)
    return store
end

row(t::TempStore) = (t.id, string(t.algo), string(t.data),)
function store!(s::AbstractStore; db=DB)
    r = row(s)
    execute(db.conn, "BEGIN;")
    execute(db.conn, "CREATE TABLE IF NOT EXISTS $(TABLENAME) $(schema(s))")
    execute(db.conn,
        "INSERT INTO games (id, algo, data) VALUES (\'$(join(r, "\',\'"))\');",
    )
    execute(db.conn, "COMMIT;")
end

function store!(id; db=DB)
    stores_ = stores(db)
    !haskey(stores_, id) && return nothing
    s = stores_[id]
    store!(s; db=db)
    delete!(stores_, id)
    return
end

function store!(id, st::SType, me, move; kwargs...)
    store(id, nothing, st, me, move; kwargs...)
    store!(id; kwargs...)
    return
end
