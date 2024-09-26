function test_tools()
    @testset "Tools" begin
        _linear_terms = Dict{Symbol,Float64}(
            :x => 0.5,
            :y => 1.0,
            :z => 2.0,
            :w => -0.25,
            :ξ => 0.0,
            :γ => 1.0,
        )

        _quadratic_terms = Dict{Tuple{Symbol,Symbol},Float64}(
            (:x, :x) => 0.5,
            (:x, :y) => 1.0,
            (:x, :z) => 2.0,
            (:x, :w) => 3.0,
            (:z, :y) => -1.0,
            (:w, :z) => -2.0,
            (:γ, :γ) => -1.0,
            (:α, :β) => 0.5,
            (:α, :β) => -0.5,
            (:β, :α) => -0.5,
            (:β, :α) => 0.5,
        )

        _linear_terms, _quadratic_terms, variable_set = QUBOTools._normal_form(
            _linear_terms,
            _quadratic_terms
        )

        variable_map, variable_inv = QUBOTools._build_mapping(variable_set)

        linear_terms, quadratic_terms = QUBOTools._map_terms(
            _linear_terms,
            _quadratic_terms,
            variable_map,
        )

        @test variable_map == Dict{Symbol,Int}(
            :w => 1, :x => 2, :y => 3, :z => 4,
            :α => 5, :β => 6, :γ => 7, :ξ => 8,
        )

        @test variable_inv == Dict{Int,Symbol}(
            1 => :w, 2 => :x, 3 => :y, 4 => :z,
            5 => :α, 6 => :β, 7 => :γ, 8 => :ξ,
        )

        @test linear_terms == Dict{Int,Float64}(
            1 => -0.25, 2 => 1.0, 3 => 1.0, 4 => 2.0,
        )

        @test quadratic_terms == Dict{Tuple{Int,Int},Float64}(
            (2, 3) => 1.0,
            (2, 4) => 2.0,
            (1, 2) => 3.0,
            (3, 4) => -1.0,
            (1, 4) => -2.0,
        )

        __linear_terms, __quadratic_terms = QUBOTools._inv_terms(
            linear_terms,
            quadratic_terms,
            variable_inv,
        )

        @test __linear_terms == Dict{Symbol,Float64}(
            :x => 1.0,
            :y => 1.0,
            :z => 2.0,
            :w => -0.25,
        )

        @test __quadratic_terms == Dict{Tuple{Symbol,Symbol},Float64}(
            (:x, :y) => 1.0,
            (:x, :z) => 2.0,
            (:w, :x) => 3.0,
            (:y, :z) => -1.0,
            (:w, :z) => -2.0,
        )

        # ~*~ Type inference ~*~ #
        @test QUBOTools.infer_model_type(:json) <: QUBOTools.BQPJSON
        @test QUBOTools.infer_model_type("file.json") <: QUBOTools.BQPJSON

        @test QUBOTools.infer_model_type(:hfs) <: QUBOTools.HFS
        @test QUBOTools.infer_model_type("file.hfs") <: QUBOTools.HFS

        @test QUBOTools.infer_model_type(:mzn) <: QUBOTools.MiniZinc
        @test QUBOTools.infer_model_type("file.mzn") <: QUBOTools.MiniZinc

        @test QUBOTools.infer_model_type(:qh) <: QUBOTools.Qubist
        @test QUBOTools.infer_model_type("file.qh") <: QUBOTools.Qubist

        @test QUBOTools.infer_model_type(:qubo) <: QUBOTools.QUBO
        @test QUBOTools.infer_model_type("file.qubo") <: QUBOTools.QUBO
    
        @test_throws Exception QUBOTools.infer_model_type(:xyz)
        @test_throws Exception QUBOTools.infer_model_type("file")
    end
end