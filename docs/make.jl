using Documenter
using MultiDocumenter

temp_dir = mktempdir()


docs = [
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBO.jl"),
        path = "QUBO.jl",
        name = "QUBO.jl",
        giturl = "https://github.com/psrenergy/QUBO.jl.git",
        branch ="gh-pages"
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "ToQUBO.jl"),
        path = "ToQUBO.jl",
        name = "ToQUBO.jl",
        giturl = "https://github.com/psrenergy/ToQUBO.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBODrivers.jl"),
        path = "QUBODrivers.jl",
        name = "QUBODrivers.jl",
        giturl = "https://github.com/psrenergy/QUBODrivers.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBOTools.jl"),
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
    rootpath = "/QUBO.jl",
)

gitroot = normpath(joinpath(@__DIR__, ".."))
run(`git pull`)
outbranch = "gh-multi-pages"
has_outbranch = true
if !success(`git checkout $outbranch`)
    has_outbranch = false
    if !success(`git checkout -b $outbranch`)
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