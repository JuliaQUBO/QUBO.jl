using MultiDocumenter

# import QUBO: QUBO

clonedir = mktempdir()

docs = [
    MultiDocumenter.DropdownNav("Packages", [
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "ToQUBO"),
            path = "ToQUBO.jl",
            name = "ToQUBO.jl",
            giturl = "https://github.com/psrenergy/ToQUBO.jl.git",
        ),
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "Anneal.jl"),
            path = "Anneal",
            name = "Anneal.jl",
            giturl = "https://github.com/psrenergy/Anneal.jl.git",
        ),
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "QUBOTools.jl"),
            path = "QUBOTools",
            name = "QUBOTools.jl",
            giturl = "https://github.com/psrenergy/QUBOTools.jl.git",
        ),
    ]),
]

outpath = mktempdir()

MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch
    )
)
