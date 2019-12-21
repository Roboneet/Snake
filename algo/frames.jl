struct Frame
	no
	state
	children
    deaths
    prev
end

Frame(state, prev) = Frame(state, [], prev)
Frame(state, deaths, prev) = Frame(state[:turn], copystate(state),
 	Dict(), deaths, prev)

function Base.show(io::IO, fr::Frame)
	println(io, fr.no)
	Base.show(io, Board(fr.state))
	println(io,  "LENGTH, HEALTH")
	println(io,
		join(map(x ->
			"$(id(x)): $(length(x)), $(health(x))",
			 filter(alive, fr.state[:snakes])),
			 "\n"))
end

function child(fr::Frame, moves, nf::Frame)
	fr.children[moves] = nf
	return nf
end


function prev(fr::Frame)
	return fr.prev
end

branches(fr) = length(values(fr.children))
nextall(fr) = collect(values(fr.children))

function next(fr::Frame, i=1)
	branches(fr) == 0 && return nothing
	n = nextall(fr)
	return n[i]
end

function endframes(fr::Frame)
	ex = [fr]
	list = []
	while !isempty(ex)
		r = popfirst!(ex)
		while r != nothing
			println(r.no)
			if length(r.deaths) != 0
				push!(list, r)
			end

			if branches(fr) > 1
				n = nextall(r)
				push!(ex, n...)
				r = nothing
			else
				r = next(r)
			end
		end
	end
	return list
end

roll(fr::Frame) = roll((x) -> (Base.show(x); true), fr)

roll(f, ::Nothing) = nothing
function roll(f, fr::Frame; next=next)
	f(fr)
	roll(f, next(fr))
end

struct STOP <: Exception
	fr
end

function stopat(f, fr::Frame)
	t = fr
	try
		roll(fr) do x
			stop = f(x)
			stop ? throw(STOP(x)) : nothing
		end
	catch e
		isa(e, STOP) && return e.fr
		rethrow(e)
	end

end

function endof(fr::Frame)
	e = fr
	roll(fr) do x
		k = next(x) == nothing
		if k
			e = x
		end
	end
	return e
end

function Base.length(fr::Frame)
	l = 0
	roll(fr) do x
		l += 1
	end
	return l
end

function treeview(fr::Frame, padding=0)
	for (k, v) in pairs(fr.children)
		print(" "^padding)
		println(k)
		treeview(v, padding + 2)
	end
end

function goto(fr::Frame, n)
	stopat(fr) do x
		x.no >= n
	end
end
