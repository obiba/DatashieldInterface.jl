using DatashieldInterface
using Test

include("test_helpers.jl")

@testset "DatashieldInterface" begin
    include("logintbuilder_tests.jl")
    include("utils_tests.jl")
    include("errors_tests.jl")
    include("client_tests.jl")
end
