function test_error()
    @testset "Error" begin
        @test_throws QUBOTools.QUBOCodecError QUBOTools.codec_error()
        @test_throws QUBOTools.SampleError QUBOTools.sample_error()
    end
end