struct Model{D} <: QUBOTools.AbstractQUBOModel{D}
    backend
end

QUBOTools.backend(m::Model) = m.backend

function test_interface()
    V = Symbol
    U = Int
    T = Float64
    B = BoolDomain
    S = SpinDomain

    null_model = Model{B}(
        QUBOTools.StandardQUBOModel{V,U,T,B}(
            Dict{V,T}(),
            Dict{Tuple{V,V},T}()
        )
    )

    bool_model = Model{B}(
        QUBOTools.StandardQUBOModel{V,U,T,B}(
            Dict{V,T}(:x => 1.0, :y => -1.0),
            Dict{Tuple{V,V},T}((:x, :y) => 2.0);
            scale=2.0,
            offset=1.0
        )
    )

    spin_model = Model{S}(
        QUBOTools.StandardQUBOModel{V,U,T,S}(
            Dict{V,T}(:x => 1.0),
            Dict{Tuple{V,V},T}((:x, :y) => 0.5);
            scale=2.0,
            offset=1.5
        )
    )

    @testset "-*- Interface" verbose = true begin
        @test QUBOTools.backend(null_model) isa QUBOTools.StandardQUBOModel
        @test QUBOTools.backend(bool_model) isa QUBOTools.StandardQUBOModel
        @test QUBOTools.backend(spin_model) isa QUBOTools.StandardQUBOModel
        @test isempty(null_model)
        @test !isempty(bool_model)
        @test !isempty(spin_model)
        @test isvalid(bool_model)
        @test isvalid(spin_model)

        @testset "Data access" begin
            @test QUBOTools.scale(null_model) == 1.0
            @test QUBOTools.scale(bool_model) == 2.0
            @test QUBOTools.scale(spin_model) == 2.0
            @test QUBOTools.offset(null_model) == 0.0
            @test QUBOTools.offset(bool_model) == 1.0
            @test QUBOTools.offset(spin_model) == 1.5
        end

        @testset "Queries" begin
            @test QUBOTools.model_name(bool_model) == "Model{BoolDomain}"
            @test QUBOTools.model_name(spin_model) == "Model{SpinDomain}"
            @test QUBOTools.domain_name(bool_model) == "Bool"
            @test QUBOTools.domain_name(spin_model) == "Spin"
            @test QUBOTools.domain_size(null_model) == 0
            @test QUBOTools.domain_size(bool_model) == 2
            @test QUBOTools.domain_size(spin_model) == 2
            @test QUBOTools.linear_size(null_model) == 0
            @test QUBOTools.linear_size(bool_model) == 2
            @test QUBOTools.linear_size(spin_model) == 1
            @test QUBOTools.quadratic_size(null_model) == 0
            @test QUBOTools.quadratic_size(bool_model) == 1
            @test QUBOTools.quadratic_size(spin_model) == 1

            @test QUBOTools.density(null_model) |> isnan
            @test QUBOTools.density(bool_model) ≈ 1.0
            @test QUBOTools.density(spin_model) ≈ 0.75
            @test QUBOTools.linear_density(null_model) |> isnan
            @test QUBOTools.linear_density(bool_model) ≈ 1.0
            @test QUBOTools.linear_density(spin_model) ≈ 0.5
            @test QUBOTools.quadratic_density(null_model) |> isnan
            @test QUBOTools.quadratic_density(bool_model) ≈ 1.0
            @test QUBOTools.quadratic_density(spin_model) ≈ 1.0

            @test QUBOTools.variable_map(bool_model, :x) == 1
            @test QUBOTools.variable_map(spin_model, :x) == 1
            @test QUBOTools.variable_map(bool_model, :y) == 2
            @test QUBOTools.variable_map(spin_model, :y) == 2
            @test QUBOTools.variable_inv(bool_model, 1) == :x
            @test QUBOTools.variable_inv(spin_model, 1) == :x
            @test QUBOTools.variable_inv(bool_model, 2) == :y
            @test QUBOTools.variable_inv(spin_model, 2) == :y

            @test_throws Exception QUBOTools.variable_map(bool_model, :z)
            @test_throws Exception QUBOTools.variable_map(spin_model, :z)
            @test_throws Exception QUBOTools.variable_inv(bool_model, -1)
            @test_throws Exception QUBOTools.variable_inv(spin_model, -1)
        end

        @testset "Normal Forms" begin
            let (Q, α, β) = QUBOTools.qubo(Dict, T, bool_model)
                @test Q == Dict{Tuple{Int,Int},T}((1, 1) => 1.0, (1, 2) => 2.0, (2, 2) => -1.0)
                @test α == 2.0
                @test β == 1.0
            end

            let (Q, α, β) = QUBOTools.qubo(Array, T, bool_model)
                @test Q == [1.0 2.0; 0.0 -1.0]
                @test α == 2.0
                @test β == 1.0
            end

            let (h, J, α, β) = QUBOTools.ising(Dict, T, bool_model)
                @test h == Dict{Int,T}(1 => 1.0, 2 => 0.0)
                @test J == Dict{Tuple{Int,Int},T}((1, 2) => 0.5)
                @test α == 2.0
                @test β == 1.5
            end

            let (h, J, α, β) = QUBOTools.ising(Array, T, bool_model)
                @test h == [1.0, 0.0]
                @test J == [0.0 0.5; 0.0 0.0]
                @test α == 2.0
                @test β == 1.5
            end

            @test QUBOTools.qubo(bool_model) == QUBOTools.qubo(Dict, T, bool_model)
            @test QUBOTools.ising(bool_model) == QUBOTools.ising(Dict, T, bool_model)

            let (Q, α, β) = QUBOTools.qubo(Dict, T, spin_model)
                @test Q == Dict{Tuple{Int,Int},T}((1, 1) => 1.0, (1, 2) => 2.0, (2, 2) => -1.0)
                @test α == 2.0
                @test β == 1.0
            end

            let (Q, α, β) = QUBOTools.qubo(Array, T, spin_model)
                @test Q == [1.0 2.0; 0.0 -1.0]
                @test α == 2.0
                @test β == 1.0
            end

            let (h, J, α, β) = QUBOTools.ising(Dict, T, spin_model)
                @test h == Dict{Int,T}(1 => 1.0, 2 => 0.0)
                @test J == Dict{Tuple{Int,Int},T}((1, 2) => 0.5)
                @test α == 2.0
                @test β == 1.5
            end

            let (h, J, α, β) = QUBOTools.ising(Array, T, spin_model)
                @test h == [1.0, 0.0]
                @test J == [0.0 0.5; 0.0 0.0]
                @test α == 2.0
                @test β == 1.5
            end

            @test QUBOTools.qubo(spin_model) == QUBOTools.qubo(Dict, T, spin_model)
            @test QUBOTools.ising(spin_model) == QUBOTools.ising(Dict, T, spin_model)
        end

        @testset "Energy" begin
            bool_states = [[0, 0], [0, 1], [1, 0], [1, 1]]
            spin_states = [2x .- 1 for x in bool_states]
            
            energy_values = [2.0, 0.0, 4.0, 6.0]

            for (x, s, e) in zip(bool_states, spin_states, energy_values)
                @test QUBOTools.energy(x, bool_model) == e
                @test QUBOTools.energy(s, spin_model) == e
            end
        end
    end
end