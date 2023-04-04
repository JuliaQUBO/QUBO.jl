using MultiDocumenter

# import QUBO: QUBO

temp_dir = mktempdir()

docs = [

    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "ToQUBO"),
        path = "ToQUBO.jl",
        name = "ToQUBO.jl",
        giturl = "https://github.com/psrenergy/ToQUBO.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "Anneal.jl"),
        path = "Anneal.jl",
        name = "Anneal.jl",
        giturl = "https://github.com/psrenergy/Anneal.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBOTools.jl"),
        path = "QUBOTools.jl",
        name = "QUBOTools.jl",
        giturl = "https://github.com/psrenergy/QUBOTools.jl.git",
    ),
    
]


outpath = joinpath(@__DIR__, "build")


MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch
    ),
    rootpath = "/QUBO.jl/index.md",
)


# gitroot = joinpath(tempdir(), "build")
# run(`git pull`)
# outbranch = "gh-pages"
# has_outbranch = true
# if !success(`git checkout $outbranch`)
#     has_outbranch = false
#     if !success(`git checkout -b $outbranch`)
#         @error "Cannot create new orphaned branch $outbranch."
#         exit(1)
#     end
# end
# for file in readdir(gitroot; join = true)
#     endswith(file, ".git") && continue
#     rm(file; force = true, recursive = true)
# end
# for file in readdir(outpath)
#     cp(joinpath(outpath, file), joinpath(gitroot, file))
# end
# run(`git add .`)
# if success(`git commit -m 'Aggregate documentation'`)
#     @info "Pushing updated documentation."
#     if has_outbranch
#         run(`git push`)
#     else
#         run(`git push -u origin $outbranch`)
#     end
#     run(`git checkout master`)
# else
#     @info "No changes to aggregated documentation."
# end