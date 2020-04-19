# using DataFrames

function move(req, wa=whichalgo)
    d = JSON.parse(String(copy(req[:data])))
    ex = extract(d)
    st = ex[:state]
    me = ex[:me]
    algo = wa(req)
    move = findmove(algo, st, me)
    if USE_REDIS
        keep(ex[:gameid], algo, st, me, move)
    end
    return JSON.json((move=eng(move),))
end

test_intersect(req) = move(req, (r) -> sls(parse(Int, r[:params][:n])))


function foo(req)
    ex = extract(JSON.parse(String(req[:data])))
    st = ex[:state]
    # store in the db when /end is pinged
    if USE_REDIS
        keep(ex[:gameid], :end, st, ex[:me])
    end
    io = IOBuffer()
    println(io, st.turn)
    showcells(io, st)
    println(String(take!(io)))
    return "ok"
end

function start(req)
    JSON.json((color="#8752ef",))
end

function test_store(req)
    db = Persistence("testdb")
    id = string(rand(1:10_000))
    default_store(i) = store(id, :TEST, SType(i), 0, (0, 0), db=db)
    default_store.(1:10)
    store!(id, SType(11), 0, (0, 0), db=db)
    df = DataFrame(execute(db.conn, "SELECT * FROM games;"))
    println(df)
    return string(df)
end
