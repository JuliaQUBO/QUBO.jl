function test_docs_assets()
    @testset "Docs Assets" begin
        css = read(joinpath(@__DIR__, "..", "docs", "src", "assets", "extra_styles.css"), String)

        @test occursin("--qubo-package-card-border", css)
        @test occursin("--qubo-package-card-background", css)
        @test !occursin("--documenter-border-color", css)
        @test !occursin("--documenter-sidebar-background", css)
    end

    return nothing
end
