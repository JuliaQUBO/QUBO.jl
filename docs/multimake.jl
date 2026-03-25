using Documenter
using MultiDocumenter

include("multimake_utils.jl")

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
    remote::String = "origin",
)
    root_path = normpath(joinpath(@__DIR__, ".."))

    # We do not run `git pull` here because in CI environments (like GitHub Actions),
    # the repository is often in a detached HEAD state, which causes `git pull` to fail.
    # We assume the environment is already set up with the correct commit to build.

    checkout_deploy_branch(branch; remote)

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
        push_deploy_branch(branch; remote)

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
