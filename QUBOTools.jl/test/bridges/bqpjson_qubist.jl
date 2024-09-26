function test_bqpjson_qubist(path::String, n::Integer)
    @testset "BQPJSON ~ Qubist" begin
        for i = 0:n
            qubs_path = QUBIST_PATH(path, i)
            spin_path = BQPJSON_SPIN_PATH(path, i)

            qubs_model = read(qubs_path, Qubist)
            spin_model = read(spin_path, BQPJSON)

            @test qubs_model isa Qubist{SpinDomain}
            @test spin_model isa BQPJSON{SpinDomain}

            @test QUBOTools.__isvalidbridge(
                convert(Qubist{SpinDomain}, spin_model),
                qubs_model,
                BQPJSON{SpinDomain},
            )
            @test QUBOTools.__isvalidbridge(
                convert(BQPJSON{SpinDomain}, qubs_model),
                spin_model,
                Qubist{SpinDomain},
            )
        end
    end
end