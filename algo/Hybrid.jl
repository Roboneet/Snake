# strategy B when K or less snakes are left
# otherwise use A
struct Earthworm{K,A,B} <: AbstractAlgo end

function pipe(::Type{Earthworm{K,A,B}}, s::SType, i::Int) where {K,A,B}
    if s.ns <= K
        return pipe(B, s, i)
    else
        return pipe(A, s, i)
    end
end
