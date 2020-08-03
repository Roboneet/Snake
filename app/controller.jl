include("utils.jl")
# include("store.jl")

algoDict = Dict()
algoDict["default"] = Grenade
algoDict["grenade"] = Grenade
algoDict["cupcake"] = Cupcake
algoDict["kettle"] = Kettle
algoDict["wip"] = sls(4)
algoDict["rainbow"] = Earthworm{3,Grenade,TreeSearch{NotBad,Punk,SeqLocalSearch{2}}}
algoDict["antimatter"] = TreeSearch{NotBad,Punk,SeqLocalSearch{2}}
algoDict["diamond"] = PartialExplore

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
		  @show name
		  # simple names (types without parameters) will work
		  algoDict[name] = eval(Meta.parse(name))
	  end
	  f(req)
   end
end

include("views.jl")
function pages(start, fs...)
	PAGE = (x) -> page(x...)
	prepend = (x) -> (y -> "$x$y")
	PAGE.(zip(prepend(start).(("/", "/start", "/move", "/ping", "/end")),
			 fs))
end

@app sankeserver = (
   logger,
   IS_PROD ? Mux.prod_defaults : Mux.defaults,
   page("/", respond("<h1>bla ble blue..... I'm fine, thanks :)</h1>")),
   pages("/:s", snake_info, start, move, respond("ok"), foo)...,
   pages("/test/:s", snake_info, test(start), test(move), respond("ok"), foo)...,
   page("/test/store/", test_store),
   Mux.notfound())
