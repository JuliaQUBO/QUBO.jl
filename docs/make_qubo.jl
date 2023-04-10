using Documenter

makedocs(;
    doctest=true,
    clean=true,
    format=Documenter.HTML(
        # assets = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine=Documenter.MathJax2(),
        sidebar_sitename=false,
    ), 
    sitename="QUBO.jl",
    authors="Pedro Xavier and Pedro Ripper and Tiago Andrade and Joaquim Garcia and David Bernal",
    pages=[
        "Home" => "index.md"
    ],
    workdir="."
)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploydocs(
        repo=raw"github.com/psrenergy/QUBO.jl.git",
        push_preview = true
    )
end