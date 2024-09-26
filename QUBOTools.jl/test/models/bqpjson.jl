const BQPJSON_ATOL = 1E-12

BQPJSON_BOOL_PATH(path::String, i::Integer)      = joinpath(path, "data", @sprintf("%02d", i), "bool.json")
BQPJSON_SPIN_PATH(path::String, i::Integer)      = joinpath(path, "data", @sprintf("%02d", i), "spin.json")
BQPJSON_BOOL_TEMP_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "bool.temp.json")
BQPJSON_SPIN_TEMP_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "spin.temp.json")

function test_bqpjson(path::String, n::Integer)
    @testset "BQPJSON" verbose = true begin
        @testset "IO" verbose = true begin
            @testset "BOOL" begin
                for i = 0:n
                    bool_path      = BQPJSON_BOOL_PATH(path, i)
                    bool_temp_path = BQPJSON_BOOL_TEMP_PATH(path, i)
                    try
                        bool_model = read(bool_path, BQPJSON)
                        @test bool_model isa BQPJSON{BoolDomain}

                        write(bool_temp_path, bool_model)

                        temp_model = read(bool_temp_path, BQPJSON)
                        @test temp_model isa BQPJSON{BoolDomain}

                        @test QUBOTools.__isvalidbridge(
                            temp_model,
                            bool_model,
                            BQPJSON{BoolDomain},
                        )
                    catch e
                        rethrow(e)
                    finally
                        rm(bool_temp_path)
                    end
                end
            end

            @testset "SPIN" begin
                for i = 0:n
                    spin_path      = BQPJSON_SPIN_PATH(path, i)
                    spin_temp_path = BQPJSON_SPIN_TEMP_PATH(path, i)
                    try
                        spin_model = read(spin_path, BQPJSON)
                        @test spin_model isa BQPJSON{SpinDomain}

                        write(spin_temp_path, spin_model)

                        temp_model = read(spin_temp_path, BQPJSON)
                        @test temp_model isa BQPJSON{SpinDomain}

                        @test QUBOTools.__isvalidbridge(
                            temp_model,
                            spin_model,
                            BQPJSON{BoolDomain};
                            atol = 0.0,
                        )
                    catch e
                        rethrow(e)
                    finally
                        rm(spin_temp_path; force = true)
                    end
                end
            end
        end

        @testset "Bridges" verbose = true begin
            @testset "SPIN ~ BOOL" begin
                for i = 0:n
                    bool_model = read(joinpath(path, "data", "0$(i)", "bool.json"), BQPJSON{BoolDomain})
                    spin_model = read(joinpath(path, "data", "0$(i)", "spin.json"), BQPJSON{SpinDomain})

                    @test QUBOTools.__isvalidbridge(
                        convert(BQPJSON{BoolDomain}, spin_model),
                        bool_model,
                        BQPJSON{SpinDomain};
                        atol=BQPJSON_ATOL
                    )

                    @test QUBOTools.__isvalidbridge(
                        convert(BQPJSON{SpinDomain}, bool_model),
                        spin_model,
                        BQPJSON{BoolDomain};
                        atol=BQPJSON_ATOL
                    )
                end
            end
        end
    end
end