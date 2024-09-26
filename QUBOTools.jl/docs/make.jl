using Documenter
using QUBOTools

# Set up to run docstrings with jldoctest
DocMeta.setdocmeta!(
    QUBOTools, :DocTestSetup, :(using QUBOTools); recursive=true
)

makedocs(;
    modules=[QUBOTools],
    doctest=true,
    clean=true,
    format=Documenter.HTML(
        assets = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine=Documenter.MathJax2(),
        sidebar_sitename=false,
    ), 
    sitename="QUBOTools.jl",
    authors="Pedro Xavier and Tiago Andrade and Joaquim Garcia and David Bernal",
    pages=[
        "Home" => "index.md",
        "manual.md",
    ],
    workdir="."
)

# deploydocs(
#     repo=raw"github.com/psrenergy/QUBOTools.jl.git",
#     push_preview = true
# )