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

# Mutant tree search

struct Mutant <: AbstractAlgo end

function pipe(::Type{Mutant}, s::SType, i::Int)
	if s.ns <= 3
		return pipe(TreeSearch{NotBad,Punk,CandleLight{2}}, s, i)
	else 
		return pipe(TreeSearch{NotBad,Punk,SeqLocalSearch{2}}, s, i)
	end
end
