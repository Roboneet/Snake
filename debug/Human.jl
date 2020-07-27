using REPL.TerminalMenus

abstract type AbstractExternal <: AbstractAlgo end

input_src(::Type{T}) where T <: AbstractExternal =
    error("not implemented for type $T")
getmoves(::Type{T}, st::SType, i::Int, l::UInt32) where T <: AbstractExternal =
    error("not implemented for type $T")

function pipe(::Type{T}, st, i) where T <: AbstractExternal
    return  y -> begin
        c, d, r = reachableclusters(cells(st), st.snakes)
        # println(colorarray(c, d, r, i))
        l = TerminalMenus.readKey(input_src(T))
        return getmoves(T, st, i, l)
    end
end

struct Human <: AbstractExternal end

input_src(::Type{Human}) = stdin
key_map = Dict(
    1000=> (0, -1),
    1001=> (0, 1),
    1002=> (-1, 0),
    1003=> (1, 0)
)


function getmoves(::Type{Human}, st::SType, i::Int, l::UInt32)
    b = basic(st, i)
    k = key_map[l]
    # because humans can make silly mistakes... especially me!
    !in(k, b) && return b
    return [k]
end

# struct Client <: AbstractExternal
# 	ip
# 	port
# end

# function pipe(c::Client, st::SType, i::Int)
# 	getmove(c, st, i)
# end

# using Sockets

# function getmove(c::Client, st::SType, i::Int)
# 	sock = connect

# end
