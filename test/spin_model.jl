function test_spin_model()
    @testset "Spin Model" begin
        h = [-1 -1 -1]
        J = [
            0 2 2
            0 0 2
            0 0 0
        ]
        
        model = Model(ExactSampler.Optimizer)

        @variable(model, s[1:3], Spin)
        @objective(model, Min, h's + s' * J * s)

        optimize!(model)

        @test objective_value(model) ≈ -3.0
    end

    return nothing
end