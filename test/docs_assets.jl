function test_docs_assets()
    @testset "Docs Assets" begin
        assets_dir = joinpath(@__DIR__, "..", "docs", "src", "assets")
        css = read(joinpath(assets_dir, "extra_styles.css"), String)
        qubodrivers_logo = read(joinpath(assets_dir, "logo-qubodrivers.svg"), String)
        qubotools_logo = read(joinpath(assets_dir, "logo-qubotools.svg"), String)

        @test occursin("--qubo-package-card-border", css)
        @test occursin("--qubo-package-card-background", css)
        @test !occursin("--documenter-border-color", css)
        @test !occursin("--documenter-sidebar-background", css)

        @test occursin("M 671.76 94.861", qubodrivers_logo)
        @test occursin("vector-effect=\"non-scaling-stroke\"", qubodrivers_logo)
        @test occursin("M 596.402 68.044", qubotools_logo)
        @test occursin("vector-effect=\"non-scaling-stroke\"", qubotools_logo)
    end

    return nothing
end
