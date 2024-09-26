using Documenter
using MultiDocumenter

temp_dir = mktempdir()

docs = [
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBO.jl"),
        path = "QUBO.jl",
        name = "QUBO.jl",
        giturl = "https://github.com/JuliaQUBO/QUBO.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "ToQUBO.jl"),
        path = "ToQUBO.jl",
        name = "ToQUBO.jl",
        giturl = "https://github.com/JuliaQUBO/ToQUBO.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBODrivers.jl"),
        path = "QUBODrivers.jl",
        name = "QUBODrivers.jl",
        giturl = "https://github.com/JuliaQUBO/QUBODrivers.jl.git",
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(temp_dir, "QUBOTools.jl"),
        path = "QUBOTools.jl",
        name = "QUBOTools.jl",
        giturl = "https://github.com/JuliaQUBO/QUBOTools.jl.git",
    ),
]

function buildmultidocs(path::AbstractString, docs)
    MultiDocumenter.make(
        path,
        docs;
        search_engine = MultiDocumenter.SearchConfig(
            index_versions = ["stable"],
            engine = MultiDocumenter.FlexSearch,
        ),
        rootpath = "/QUBO.jl",
    )

    return nothing
end

function deploymultidocs(
    path::AbstractString;
    branch::String = "gh-multi-pages",
    main::String = "main",
)
    root_path = normpath(joinpath(@__DIR__, ".."))

    run(`git status`)

    run(`git pull`)

    run(`git status`)

    has_branch = true

    run(`git checkout $branch`)

    run(`git status`)

    exit(1)

    if !success(`git checkout $branch`)
        has_branch = false

        if !success(`git switch --orphan --discard-changes $branch`)
            @error "Cannot create new orphaned branch $branch."

            exit(1)
        end
    end

    for file in readdir(root_path; join = true)
        endswith(file, ".git") && continue

        rm(file; force = true, recursive = true)
    end

    # mkpath(path) # creates if not exists

    for file in readdir(path)
        cp(joinpath(path, file), joinpath(root_path, file))
    end

    run(`git add .`)

    if success(`git commit -m 'Aggregate documentation'`)
        @info "Pushing updated documentation"

        if has_branch
            run(`git push`)
        else
            run(`git push -u origin $branch`)
        end

        run(`git checkout $main`)
    else
        @info "No changes to aggregated documentation"
    end

    return nothing
end

build_path = mktempdir()

buildmultidocs(build_path, docs)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploymultidocs(build_path; main = "master")
end
