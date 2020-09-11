function move(req, wa=whichalgo) 
    parsetime = @elapsed d = JSON.parse(String(copy(req[:data])))
    ex = extract(d)
    st = ex[:state]
    me = ex[:me]
    algo = wa(req)
    evaltime = @elapsed move = findmove(algo, st, me)
    k = eng(move)
	# println("Metrics (algo: $(algo), parsetime: $(parsetime), evaltime: $(evaltime))")
	return JSON.json((move=k,))
end

function foo(req)
    # ex = extract(JSON.parse(String(req[:data])))
    # st = ex[:state]
    # io = IOBuffer()
    # println(io, st.turn)
    # showcells(io, st)
    # println(String(take!(io)))
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
