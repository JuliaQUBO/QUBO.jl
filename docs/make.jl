using MultiDocumenter

# import QUBO: QUBO

clonedir = mktempdir()

docs = [

    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "ToQUBO"),
        path = "ToQUBO.jl",
        name = "ToQUBO.jl",
        giturl = "https://github.com/psrenergy/ToQUBO.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "Anneal.jl"),
        path = "Anneal.jl",
        name = "Anneal.jl",
        giturl = "https://github.com/psrenergy/Anneal.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "QUBOTools.jl"),
        path = "QUBOTools.jl",
        name = "QUBOTools.jl",
        giturl = "https://github.com/psrenergy/QUBOTools.jl.git",
    ),
    
]


outpath = mktempdir()


MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch
    ),
    rootpath = "/QUBO.jl/",
)

gitroot = normpath(joinpath(@__DIR__, ".."))
run(`git pull`)
outbranch = "gh-pages"
has_outbranch = true
if !success(`git checkout $outbranch`)
    has_outbranch = false
    if !success(`git switch --orphan $outbranch`)
        @error "Cannot create new orphaned branch $outbranch."
        exit(1)
    end
end
for file in readdir(gitroot; join = true)
    endswith(file, ".git") && continue
    rm(file; force = true, recursive = true)
end
for file in readdir(outpath)
    cp(joinpath(outpath, file), joinpath(gitroot, file))
end
run(`git add .`)
if success(`git commit -m 'Aggregate documentation'`)
    @info "Pushing updated documentation."
    if has_outbranch
        run(`git push`)
    else
        run(`git push -u origin $outbranch`)
    end
    run(`git checkout master`)
else
    @info "No changes to aggregated documentation."
end