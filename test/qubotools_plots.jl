using RecipesBase

struct DummyQUBOToolsBackend end

QUBOTools.backend(::DummyQUBOToolsBackend) = :dummy_backend

struct DummyJuMPModel <: JuMP.AbstractModel
    backend::DummyQUBOToolsBackend
end

JuMP.unsafe_backend(model::DummyJuMPModel) = model.backend

function solved_qubo_model()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:3], Bin)
    @objective(model, Min, x[1] * x[2] + x[2] * x[3] - x[1] - x[3])

    optimize!(model)

    return model
end

function test_qubotools_plots()
    @testset "QUBOTools Plots" begin
        @test QUBOTools.backend(DummyJuMPModel(DummyQUBOToolsBackend())) === :dummy_backend

        model = solved_qubo_model()

        backend = QUBOTools.backend(model)

        @test backend isa QUBOTools.Model
        @test QUBOTools.dimension(backend) == 3

        for plot_type in (
            QUBOTools.ModelDensityPlot,
            QUBOTools.SystemLayoutPlot,
            QUBOTools.EnergyFrequencyPlot,
            QUBOTools.EnergyDistributionPlot,
        )
            plot = plot_type(model)
            recipe_output = RecipesBase.apply_recipe(Dict{Symbol,Any}(), plot)

            @test !isempty(recipe_output)
        end
    end

    return nothing
end
