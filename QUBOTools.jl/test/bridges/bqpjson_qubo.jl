function test_bqpjson_qubo(path::String, n::Integer)
    @testset "BQPJSON ~ QUBO" begin
        for i = 0:n
            qubo_path = QUBO_PATH(path, i)
            bool_path = BQPJSON_BOOL_PATH(path, i)

            qubo_model = read(qubo_path, QUBO)
            bool_model = read(bool_path, BQPJSON)

            @test qubo_model isa QUBO{BoolDomain}
            @test bool_model isa BQPJSON{BoolDomain}

            @test QUBOTools.__isvalidbridge(
                convert(QUBO{BoolDomain}, bool_model),
                qubo_model,
                BQPJSON{BoolDomain};
                atol=BQPJSON_ATOL,
            )
            @test QUBOTools.__isvalidbridge(
                convert(BQPJSON{BoolDomain}, qubo_model),
                bool_model,
                QUBO{BoolDomain};
                atol=BQPJSON_ATOL,
            )
        end
    end
end