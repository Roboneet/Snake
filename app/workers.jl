
include("./main.jl")

# 2 min gap between worker start
function exec_later(i) 
	@spawnat i begin 
		sleep(i*120)
		include("./main.jl")
	end
end
exec_later(1)
# exec_later(2)

Base.JLOptions().isinteractive==0 && wait()
