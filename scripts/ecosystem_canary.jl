#!/usr/bin/env julia

using Pkg

function parse_args(args)
    tier = "custom"
    allow_import_failure = Set{String}()
    packages = String[]
    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--tier"
            index == length(args) && error("--tier requires a value")
            tier = args[index + 1]
            index += 2
        elseif arg == "--allow-import-failure"
            index == length(args) && error("--allow-import-failure requires a package name")
            push!(allow_import_failure, args[index + 1])
            index += 2
        elseif startswith(arg, "--")
            error("unknown option: $arg")
        else
            push!(packages, arg)
            index += 1
        end
    end
    isempty(packages) && error("at least one package is required")
    return tier, allow_import_failure, packages
end

function ensure_general_registry()
    registries = Pkg.Registry.reachable_registries()
    if isempty(registries)
        Pkg.Registry.add("General")
    else
        Pkg.Registry.update()
    end
end

function print_compat_matrix(packages)
    script = joinpath(@__DIR__, "compat_matrix.jl")
    isfile(script) || return
    try
        run(`$(Base.julia_cmd()) $script $(packages)`)
    catch err
        @warn "compat matrix failed" exception = (err, catch_backtrace())
    end
end

function resolve_packages(tier, packages)
    println("Ecosystem canary tier: $tier")
    println("Packages: $(join(packages, ", "))")
    Pkg.activate(; temp = true)
    ensure_general_registry()
    try
        Pkg.add(packages)
        Pkg.resolve()
        Pkg.status()
    catch err
        println()
        println("Julia package resolution failed for $tier.")
        println("Compatibility matrix for this tier:")
        print_compat_matrix(packages)
        println()
        showerror(stdout, err, catch_backtrace())
        println()
        exit(1)
    end
end

function import_package(name)
    if !occursin(r"^[A-Za-z_][A-Za-z0-9_]*$", name)
        error("invalid package name: $name")
    end
    Base.eval(Main, Meta.parse("using $name"))
end

function smoke_import(packages, allow_import_failure)
    failed = false
    for package in packages
        print("Importing $package ... ")
        try
            import_package(package)
            println("ok")
        catch err
            println("failed")
            if package in allow_import_failure
                @warn "optional import failed after successful resolution" package exception = (err, catch_backtrace())
            else
                showerror(stdout, err, catch_backtrace())
                println()
                failed = true
            end
        end
    end
    failed && exit(1)
end

function main(args)
    tier, allow_import_failure, packages = parse_args(args)
    resolve_packages(tier, packages)
    smoke_import(packages, allow_import_failure)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
