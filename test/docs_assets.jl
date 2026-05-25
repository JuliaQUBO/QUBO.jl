function test_docs_assets()
    @testset "Docs Assets" begin
        assets_dir = joinpath(@__DIR__, "..", "docs", "src", "assets")
        docs_dir = joinpath(@__DIR__, "..", "docs", "src")
        css = read(joinpath(assets_dir, "extra_styles.css"), String)
        mermaid_js = read(joinpath(assets_dir, "mermaid-init.js"), String)
        design = read(joinpath(docs_dir, "design.md"), String)
        qubodrivers_logo = read(joinpath(assets_dir, "logo-qubodrivers.svg"), String)
        qubotools_logo = read(joinpath(assets_dir, "logo-qubotools.svg"), String)

        @test occursin("--qubo-package-card-border", css)
        @test occursin("--qubo-package-card-background", css)
        @test !occursin("--documenter-border-color", css)
        @test !occursin("--documenter-sidebar-background", css)
        @test occursin("pre.mermaid", css)
        @test occursin("mermaid@10.9.6/dist/mermaid.esm.min.mjs", mermaid_js)
        @test occursin("renderMermaidDiagrams", mermaid_js)

        @test occursin("M 671.76 94.861", qubodrivers_logo)
        @test occursin("vector-effect=\"non-scaling-stroke\"", qubodrivers_logo)
        @test occursin("M 596.402 68.044", qubotools_logo)
        @test occursin("vector-effect=\"non-scaling-stroke\"", qubotools_logo)

        @test occursin("class=\"mermaid\"", design)
        @test occursin("QUBODrivers.jl", design)
        @test occursin("QUBOTools.jl", design)
        @test occursin("pseudo-Boolean", design)
        @test occursin("quadratization", design)
    end

    return nothing
end
