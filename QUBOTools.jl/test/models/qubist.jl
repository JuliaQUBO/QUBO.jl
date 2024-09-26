QUBIST_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "spin.qh")
QUBIST_TEMP_PATH(path::String, i::Integer) = joinpath(path, "data", @sprintf("%02d", i), "spin.temp.qh")

function test_qubist(path::String, n::Integer)
    @testset "Qubist" verbose = true begin
        @testset "IO" begin
            for i = 0:n
                qbst_path = QUBIST_PATH(path, i)
                temp_path = QUBIST_TEMP_PATH(path, i)
                try
                    qbst_model = read(qbst_path, Qubist)
                    @test qbst_model isa Qubist{SpinDomain}

                    write(temp_path, qbst_model)

                    temp_model = read(temp_path, Qubist)
                    @test temp_model isa Qubist{SpinDomain}

                    @test QUBOTools.__isvalidbridge(
                        temp_model,
                        qbst_model,
                        Qubist{SpinDomain};
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