include("utils.jl")
# include("store.jl")

algoDict = Dict()
algoDict["default"] = Grenade
algoDict["grenade"] = Grenade
algoDict["cupcake"] = Cupcake
algoDict["kettle"] = Kettle
algoDict["wip"] = sls(4)
algoDict["peepeepoopoo"] = Earthworm{4,Grenade,sls(2)}
algoDict["antimatter"] = sls(2)

function whichalgo(req)
    if haskey(req, :params)
        name = req[:params][:s]
        if !haskey(algoDict, name)
            name = "default"
        end
    end

    return algoDict[name]
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
   page("/test/intersect/:n/move", test_intersect),
   page("/test/intersect/:n/start", start),
   page("/test/store/", test_store),
   Mux.notfound())
