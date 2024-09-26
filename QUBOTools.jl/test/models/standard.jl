function test_standard()
    # ~*~ Data ~*~ #
    _linear_terms = Dict{Symbol,Float64}(:x => 1.0, :y => 1.0)
    linear_terms = Dict{Int,Float64}(1 => 1.0, 2 => 1.0)
    _quadratic_terms = Dict{Tuple{Symbol,Symbol},Float64}((:x, :y) => -2.0)
    quadratic_terms = Dict{Tuple{Int,Int},Float64}((1, 2) => -2.0)

    variable_map = Dict{Symbol,Int}(:x => 1, :y => 2)
    variable_inv = Dict{Int,Symbol}(1 => :x, 2 => :y)

    variables = Symbol[:x, :y]
    variable_set = Set{Symbol}([:x, :y])

    scale = 2.0
    offset = 1.0

    id = 33
    version = v"2.0.0"
    description = """
    This model is a test one.
    The end.
    """
    metadata = Dict{String,Any}(
        "type" => "test_model",
    )
    sampleset_samples = QUBOTools.Sample{Int,Float64}[
        QUBOTools.Sample{Int,Float64}(Int[0, 0], 1, 2.0),
        QUBOTools.Sample{Int,Float64}(Int[0, 1], 1, 4.0),
        QUBOTools.Sample{Int,Float64}(Int[1, 0], 1, 4.0),
        QUBOTools.Sample{Int,Float64}(Int[1, 1], 1, 2.0),
    ]

    sampleset_metadata = Dict{String,Any}(
        "time" => Dict{String,Any}(
            "total" => 2.0,
            "sample" => 1.0,
        )
    )

    sampleset = QUBOTools.SampleSet{Int,Float64}(
        sampleset_samples,
        sampleset_metadata,
    )

    std_model = QUBOTools.StandardQUBOModel{Symbol,Int,Float64,QUBOTools.BoolDomain}(
        _linear_terms,
        _quadratic_terms;
        scale=scale,
        offset=offset,
        id=id,
        version=version,
        description=description,
        metadata=metadata,
        sampleset=sampleset
    )

    @testset "Standard" verbose = true begin
        @testset "Data access" verbose = true begin
            @test QUBOTools.linear_terms(std_model) == linear_terms
            @test QUBOTools.quadratic_terms(std_model) == quadratic_terms

            @test QUBOTools.variable_map(std_model) == variable_map
            @test QUBOTools.variable_map(std_model, :x) == 1
            @test QUBOTools.variable_map(std_model, :y) == 2

            @test QUBOTools.variable_inv(std_model) == variable_inv
            @test QUBOTools.variable_inv(std_model, 1) == :x
            @test QUBOTools.variable_inv(std_model, 2) == :y

            @test QUBOTools.variables(std_model) == variables
            @test QUBOTools.variable_set(std_model) == variable_set

            @test QUBOTools.scale(std_model) == scale
            @test QUBOTools.offset(std_model) == offset

            @test QUBOTools.id(std_model) == id
            @test QUBOTools.version(std_model) == version
            @test QUBOTools.description(std_model) == description
        end

        @testset "Queries" verbose = true begin
            @test isnothing(QUBOTools.backend(std_model))

            @test QUBOTools.domain(std_model) == QUBOTools.BoolDomain
            @test QUBOTools.domain_name(std_model) == "Bool"
            @test QUBOTools.domain_size(std_model) == 2

            @test QUBOTools.linear_size(std_model) == 2
            @test QUBOTools.quadratic_size(std_model) == 1

            @test QUBOTools.linear_density(std_model) ≈ 1.0
            @test QUBOTools.quadratic_density(std_model) ≈ 1.0

            @test QUBOTools.density(std_model) ≈ 1.0
        end

        @testset "Reset" verbose = true begin
            @test !isempty(std_model)
            empty!(std_model)
            @test isempty(std_model)
        end

        # @testset "Bridges" verbose = true begin
        #     @testset "BOOL -> SPIN" verbose = true begin
        #         # spin_model = convert(
        #         #     QUBOTools.StandardQUBOModel{Symbol,Int,Float64,QUBOTools.SpinDomain},
        #         #     bool_model,
        #         # )

        #         # @test QUBOTools.id(spin_model) == id
        #         # @test QUBOTools.description(spin_model) == description

        #         # @test QUBOTools.linear_terms(spin_model) == Dict{Int,Float64}()
        #         # @test QUBOTools.quadratic_terms(spin_model) == Dict{Tuple{Int,Int},Float64}(
        #         #     (1, 2) => -0.5
        #         # )
        #         # @test QUBOTools.scale(spin_model) == 1.0
        #         # @test QUBOTools.offset(spin_model) == 0.5

        #         # for x in [[0, 0], [0, 1], [1, 0], [1, 1]]
        #         #     s = 2x .- 1

        #         #     bool_energy = QUBOTools.energy(x, bool_model)
        #         #     spin_energy = QUBOTools.energy(s, spin_model)

        #         #     @test bool_energy == spin_energy
        #         # end
        #     end
        # end
    end
end