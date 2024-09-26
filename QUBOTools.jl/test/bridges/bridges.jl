include("bqpjson_minizinc.jl")
include("bqpjson_qubist.jl")
include("bqpjson_qubo.jl")

function test_bridges(path::String, n::Integer)
    @testset "-*- Bridges -*-" verbose = true begin
        test_bqpjson_minizinc(path, n)
        test_bqpjson_qubist(path, n)
        test_bqpjson_qubo(path, n)
    end
end