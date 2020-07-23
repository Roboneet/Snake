using Crayons
using REPL
using REPL.Terminals: TTYTerminal
using REPL.TerminalMenus: enableRawMode, disableRawMode, readKey

struct Frame
	no::Int
	state::SType
	children::Dict
    prev
	nodes
end

turn(fr::Frame) = fr.no
Frame(state::SType, prev) = Frame(state.turn, copystate(state),
								  Dict(), prev, 1)

haschild(fr::Frame, moves) = haskey(fr.children, moves)
child(fr::Frame, moves) = fr.children[moves]

function child(fr::Frame, moves, nf::Frame)
	fr.children[moves] = nf
	return nf
end

prev(fr::Frame) = fr.prev

function determine_width(headers, rows)
	p = length.(headers)
	for j=1:length(rows)
		for i=1:length(headers)
			p[i] = max(p[i], length(rows[j][i]))
		end
	end
	return p
end

function addpadding(w, str)
	length(str) >= w && return str
	return (" "^(w - length(str)))*str
end

module CrayonsCollection
	using Crayons

	df = Crayon(background=:default, foreground=:default)
	bd = Crayon(bold=true)
	st = Crayon(strikethrough=true)
end
cc = CrayonsCollection

function printtable(io::IO, headers, rows, alivelist)
	p = determine_width(headers, rows)
	for i=1:length(headers)
		headers[i] = addpadding(p[i], headers[i])
		for j=1:length(rows)
			rows[j][i] = addpadding(p[i], rows[j][i])
		end
	end
	cr = [merge(cc.df, cc.bd)]
	for i=1:length(rows)
		m = merge(cc.df, Crayon(background=SNAKE_COLORS[i]))
		if !alivelist[i]
			m = merge(m, cc.st)
		end
		push!(cr, m)
	end

	printtable(io, join(headers, "|"),
		map(x -> join(x, "|"), rows), cr)
end

function printtable(io::IO, headers::String,
	 	rows::T, crayons) where T <: AbstractVector{String}
	println(io, cc.df)
	print(io, crayons[1], headers)
	println(io, cc.df)
	print(io, crayons[1], "-"^length(headers))
	println(io, cc.df)
	for i=1:length(rows)
		print(io, crayons[i + 1], rows[i])
		println(io, cc.df)
	end
end

function Base.show(io::IO, fr::Frame)
	println(io, "Turn $(turn(fr))")
	Base.show(io, Board(fr.state))
	snks = fr.state.snakes
	headers = ["ID", " Length", " Health", " Death Reason"]
	rows = map(x ->
		string.([id(x), length(x),
			health(x), x.death_reason]),
		snks)
	printtable(io, headers, rows, alive.(snks))
end
