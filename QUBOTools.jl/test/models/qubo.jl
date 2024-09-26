QUBO_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "bool.qubo")
QUBO_TEMP_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "bool.temp.qubo")

function test_qubo(path::String, n::Integer)
    @testset "QUBO" verbose = true begin
        @testset "IO" begin
            for i = 0:n
                qubo_path = QUBO_PATH(path, i)
                temp_path = QUBO_TEMP_PATH(path, i)
                try
                    qubo_model = read(qubo_path, QUBO)
                    @test qubo_model isa QUBO{BoolDomain}

                    write(temp_path, qubo_model)

                    temp_model = read(temp_path, QUBO)
                    @test temp_model isa QUBO{BoolDomain}

                    @test QUBOTools.__isvalidbridge(
                        temp_model,
                        qubo_model,
                        QUBO{BoolDomain};
                        atol=0.0
                    )
                catch e
                    rethrow(e)
                finally
                    rm(temp_path; force=true)
                end
            end
        end
    end
end