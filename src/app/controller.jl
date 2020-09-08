include("utils.jl")
# include("store.jl")

const punk = TreeSearch{NotBad,Punk,SeqLocalSearch{2}}
const ff_punk = PartialExplore{PartialNotBad,PartialPunk,true}
algoDict = Dict()
algoDict["default"] = Grenade
algoDict["grenade"] = Grenade
algoDict["cupcake"] = Cupcake
algoDict["kettle"] = Kettle
# algoDict["wip"] = sls(4)
algoDict["wip"] = TreeSearch{BestCase,Coop,CandleLight{1}}
algoDict["wip_lite"] = PartialExplore{PartialBest,PartialCoop,true}
algoDict["rainbow"] = Earthworm{3,Grenade,punk}
algoDict["antimatter"] = punk
algoDict["diamond"] = ff_punk
algoDict["moon"] = Earthworm{2,ff_punk,punk}

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
	  m = f(req)
	  GC.gc()
	  return m
   end
end

function echo(f)
	return req -> begin
		@show String(copy(req[:data]))
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

default_res = (snake_info, start, move, respond("ok"), foo)

@app snakeserver = (
	logger,
	Mux.defaults,
	page("/", respond("<h1>bla ble blue..... I'm fine, thanks :)</h1>")),
	page("/test/store/", test_store),
	pages("/test/:s", test.(default_res)...)...,
	pages("/echo/:s", echo.(default_res)...)...,
	pages("/:s", default_res...)...,
	Mux.notfound())
