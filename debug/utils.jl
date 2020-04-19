# functions to read and traverse frames

cls(io) = print(io, "\x1b[H\x1b[2J")
cursor_top(io) = print(io, "\x1b[H")

link(fr) = link(fr.prev, fr)
link(pr::Nothing, fr) = nothing
function link(pr, fr)
	f = filter(x -> x[2] == fr, collect(pairs(pr.children)))
	return f[1][1]
end

branches(fr) = length(values(fr.children))
nextall(fr) = collect(values(fr.children))

function next(fr::Frame, i=1)
	branches(fr) == 0 && return nothing
	n = nextall(fr)
	return n[i]
end

function until(f, ch::Channel, cond = () -> true)
	while isempty(ch.data) && cond()
		f()
	end
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

function goto(fr::Frame, n)
	stopat(fr) do x
		x.no >= n
	end
end

terminal = REPL.TerminalMenus.terminal

function evalmsg(io, fr, f)
	df = Crayon(foreground=:default, background=:default, bold=false)
	s = string(f(fr))
	print(io, Crayon(background=:yellow, foreground=:black), "Eval: $s ", df)
	println(io, df)
end

function viewframe(out::IO, fr::Frame, f::Function)
	Base.show(out, fr)
	println(out)
	evalmsg(out, fr, f)
	println(out, "p - play | space - pause | ➡ - forward
		\nq - quit | r - replay    | ⬅ - backward")
	println(out)
end

function viewnode(out::IO, fr::Frame, f, i, msg, d)
	println(out,"Depth: $d")
	Base.show(out, fr)
	ch = next(fr, i)
	df = Crayon(foreground=:default, background=:default, bold=false)
	println(out, df)
	print(out, Crayon(bold=true), "Child $i of $(branches(fr)) children")
	println(out, df)
	println(out, df, "Link: $(collect(keys(fr.children))[i])")
	Base.show(out, Board(ch.state))
	evalmsg(out, ch, f)
	println(out, "⬅ \\ ➡ - view children | ↓ - select child
	\nq - quit               | ⬆ - select parent")
	println(out, msg)
end


function playframes(term::TTYTerminal,
	fr::Frame, l::Int, interrupt::Channel{Bool}, framech::Channel{Frame}, f)
	k = fr
	until(interrupt, () -> (next(k) != nothing)) do
		cls(term.out_stream, l)
		viewframe(term.out_stream, k, f)
		sleep(0.06)
		k = next(k)
	end
	cls(term.out_stream, l)
	viewframe(term.out_stream, k, f)
	take!(interrupt)
	put!(framech, k)
end

function nlines(buf::IO)
	s = String(take!(buf))
	l = split(s, "\n")
	return s, length(l) - 1
end

function cls(out::IO, l::Int)
	print(out, "\x1b[999D\x1b[$(l)A")
end

viewgame(fr::Frame, i::Int=1) = viewgame(terminal, fr, (args...) -> "")
viewgame(fr::Frame, i::Int, ::Type{V}) where V <: AbstractValue =
	viewgame(terminal, fr, x -> statevalue(V, x, i))
viewtree(fr::Frame, i::Int=1) = viewtree(terminal, fr, x -> "")
viewtree(fr::Frame, i::Int, ::Type{V}) where V <: AbstractValue =
	viewtree(terminal, fr, x -> statevalue(V, x, i))
function viewtree(term::TTYTerminal, fr::Frame, f)
	branches(fr) == 0 && error("single node")

	enableRawMode(term)
	print(term.out_stream, "\x1b[?25l")

	buf = IOBuffer()
	msg = ""
	viewnode(buf, fr, f, 1, msg, 1)
	s, l = nlines(buf)
	print(terminal.out_stream, s)
	k = fr
	is = [1]
	t = 1
	nb = branches(k)
	try
        while true
            c = readKey(term.in_stream)

			if c == 1001 # right arrow
				# println(term.out_stream, "YAY")
				# t = next(k)
				# if t != nothing
				# 	k = t
				# end
				if is[t] < nb
					is[t] += 1
				else
					is[t] = 1
				end
			elseif c == 1000 # left arrow key
				if is[t] > 1
					is[t] -= 1
				else
					is[t] = nb
				end
			elseif c == 1002 # arrow up
				if t > 1
					k = prev(k)
					t -= 1
					nb = branches(k)
				end
			elseif c == 1003 # arrow down
				ch = next(k, is[t])
				if branches(ch) > 0
					k = ch
					t += 1
					nb = branches(k)
					if t > length(is)
						push!(is, 1)
					end
				end
			elseif c == 113 # q
				break
			else
				# eee
			end
			cls(term.out_stream, l)
			viewnode(terminal.out_stream, k, f, is[t], msg, t)
		end
	finally
		print(term.out_stream, "\x1b[?25h")
	    disableRawMode(term)
	end
	return k
end

function viewgame(term::TTYTerminal, fr::Frame, f)
	# enable raw mode
	enableRawMode(term)
	# hide cursor
	print(term.out_stream, "\x1b[?25l")

	buf = IOBuffer()
	msg = ""
	viewframe(buf, fr, f)
	s, l = nlines(buf)
	print(terminal.out_stream, s)

	playing = false
	interrupt = Channel{Bool}(1)
	framech = Channel{Frame}(1)
	k = fr
	try
        while true
            c = readKey(term.in_stream)
			if playing
				put!(interrupt, true)
				playing = false
				# println(term.out_stream, "eeee")
				k = take!(framech)
				# println(term.out_stream, turn(k))
			end

			if c == 1001 # right arrow
				# println(term.out_stream, "YAY")
				t = next(k)
				if t != nothing
					k = t
				end

			elseif c == 112 # p
				@async playframes(term, k, l, interrupt, framech, f)
				playing = true
			elseif c == 32 # space
				# do nothing
			elseif c == 1000 # left arrow key
				t = prev(k)
				if t != nothing
					k = t
				end
			elseif c == 114 # r
				k = fr
				@async playframes(term, k, l, interrupt, framech, f)
				playing = true
			elseif c == 113 # q
				break
			else
				# eee
			end
			if !playing
				cls(term.out_stream, l)
				viewframe(terminal.out_stream, k, f)
				# println(term.out_stream, c)
			end
		end
	finally
		print(term.out_stream, "\x1b[?25h")
	    disableRawMode(term)
	end
	return k
end


function treeview(fr::Frame, padding=0; i=1, verbose=false)
	dirs = Dict(
		UP_DIR => "UP",
		LEFT_DIR => "LEFT",
		RIGHT_DIR => "RIGHT",
		DOWN_DIR => "DOWN",
		(0,0) => "_"
		)
	ch = pairs(fr.children)
	if isempty(ch)
		print(" "^padding)
		println("statevalue($(i)): $(statevalue(fr, i))")
		if verbose
			display(fr)
		end
	end
	for (k, v) in ch
		print(" "^padding)
		println(join(map(x -> dirs[x], k), ", "))
		treeview(v, padding + 2; i=i, verbose=verbose)
	end
end
