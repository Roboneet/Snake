using DataFrames

function move(req, wa=whichalgo)
    d = JSON.parse(String(copy(req[:data])))
    ex = extract(d)
    st = ex[:state]
    me = ex[:me]
    algo = wa(req)
    move = findmove(algo, st, me)
    T = Dict((1, 0)=>"down", (-1, 0)=>"up", (0, 1)=>"right", (0, -1)=>"left")
    move = T[move]
    # store in temp store
    # store(ex[:gameid], algo, st, me, move)
    return JSON.json((move=move,))
end

test_intersect(req) = move(req, (r) -> sls(parse(Int, r[:params][:n])))


function foo(req)
    ex = extract(JSON.parse(String(req[:data])))
    st = ex[:state]
    # store in the db when /end is pinged
    # store!(ex[:gameid], st, ex[:me])
    io = IOBuffer()
    println(io, st.turn)
    showcells(io, st)
    println(String(take!(io)))
    return "ok"
end

function start(req)
    JSON.json((color="#28363a",))
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
