module Snakes

include("app/main.jl")

# for package compiler
function julia_main()
	try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function real_main()
	startServer()
	Base.JLOptions().isinteractive==0 && wait()
end

if abspath(PROGRAM_FILE) == @__FILE__
    real_main()
end

end
