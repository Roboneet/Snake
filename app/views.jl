function findmove_with_timeout(algo, st, me)

end

function move(req, wa=whichalgo) 
    d = JSON.parse(String(copy(req[:data])))
    ex = extract(d)
    st = ex[:state]
    me = ex[:me]
    algo = wa(req)
    move = findmove(algo, st, me)
    k = eng(move)
	return JSON.json((move=k,shout=string(algo)))
end

function foo(req)
    ex = extract(JSON.parse(String(req[:data])))
    st = ex[:state]
    io = IOBuffer()
    println(io, st.turn)
    showcells(io, st)
    println(String(take!(io)))
    return "ok"
end

start(x) = "ok"

const color_palette = Colors.hex.(range(colorant"#a26fbb", colorant"#17847f", length=25))
function snake_info(req)
	JSON.json((apiversion="1", color="#$(rand(color_palette))",))
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
