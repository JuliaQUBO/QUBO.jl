using Documenter
using QUBO

# Set up to run docstrings with jldoctest
DocMeta.setdocmeta!(QUBO, :DocTestSetup, :(using QUBO); recursive = true)

makedocs(;
    doctest  = true,
    clean    = true,
    warnonly = [:missing_docs],
    format   = Documenter.HTML( #
        assets     = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine = Documenter.KaTeX(),
        sidebar_sitename = false
    ),
    sitename = "QUBO.jl",
    authors  = "Pedro Maciel Xavier and Pedro Ripper and Tiago Andrade and Joaquim Dias Garcia and David E. Bernal Neira",
    pages    = ["Home" => "index.md"],
    workdir  = @__DIR__
)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploydocs(repo = raw"github.com/JuliaQUBO/QUBO.jl.git", push_preview = true)
end
