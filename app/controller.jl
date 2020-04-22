include("utils.jl")
# include("store.jl")

algoDict = Dict()
algoDict["default"] = Grenade
algoDict["grenade"] = Grenade
algoDict["cupcake"] = Cupcake
algoDict["kettle"] = Kettle
algoDict["wip"] = sls(4)
algoDict["peepeepoopoo"] = Earthworm{4,Grenade,sls(2)}
algoDict["antimatter"] = TreeSearch{NotBad,SpaceValue,SeqLocalSearch{2}}

function whichalgo(req)
    if haskey(req, :params)
        name = req[:params][:s]
        if !haskey(algoDict, name)
            name = "default"
        end
    end

    return algoDict[name]
end

function test(f)
   return (req) -> begin
      name = req[:params][:s]
      if !haskey(algoDict, name)
            algoDict[name] = eval(Meta.parse(name))
            @show algoDict
      end
      f(req)
   end
end

include("views.jl")

@app sankeserver = (
   logger,
   Mux.defaults,
   page("/", respond("<h1>bla ble blue..... I'm fine, thanks :)</h1>")),
   page("/:s/start", start),
   page("/:s/move", move),
   page("/:s/ping", respond("ok")),
   page("/:s/end", foo),
   page("/test/:s/move", test(move)),
   page("/test/:s/start", test(start)),
   page("/test/store/", test_store),
   Mux.notfound())
