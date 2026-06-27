#!/usr/bin/env julia

using Pkg

const CORE_PACKAGE_NAMES = ["PseudoBooleanOptimization", "QUBOTools", "ToQUBO", "QUBODrivers"]

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
    registries = Pkg.Registry.reachable_registries()
    matches = filter(registry -> registry.name == "General", registries)
    isempty(matches) && error("General registry is not available")
    return only(matches)
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

function is_julia_compatible(compatibility)
    julia_versions = get(compatibility, Pkg.Registry.JULIA_UUID, Pkg.Types.VersionSpec())
    return VERSION in julia_versions
end

function latest_installable_registered_version(package, version_info, compatibility_info)
    candidates = VersionNumber[]
    for (version, info) in version_info
        info.yanked && continue
        isempty(version.prerelease) || continue
        is_julia_compatible(get(compatibility_info, version, Dict())) || continue
        push!(candidates, version)
    end
    if isempty(candidates)
        error("no unyanked stable release of $package is compatible with Julia $VERSION")
    end
    return maximum(candidates)
end

function latest_registered_versions(registry, package_names)
    uuid_by_name = Dict(entry.name => uuid for (uuid, entry) in registry.pkgs)
    versions = Dict{String,VersionNumber}()
    for package in package_names
        uuid = get(uuid_by_name, package, nothing)
        uuid === nothing && error("$package is not available in the General registry")
        info = Pkg.Registry.registry_info(registry.pkgs[uuid])
        compatibility_info = Pkg.Registry.compat_info(info)
        versions[package] = latest_installable_registered_version(package, info.version_info, compatibility_info)
    end
    return versions
end

function resolved_versions(package_names)
    names = Set(package_names)
    versions = Dict{String,VersionNumber}()
    for package in values(Pkg.dependencies())
        package.name in names || continue
        if package.version === nothing
            error("resolved package $(package.name) does not have a registry version")
        end
        versions[package.name] = package.version
    end
    return versions
end

function core_version_results(package_names, latest_versions, manifest_versions)
    return map(package_names) do package
        latest = get(latest_versions, package, nothing)
        resolved = get(manifest_versions, package, nothing)
        (; package, resolved, latest, ok = resolved !== nothing && resolved == latest)
    end
end

version_label(version) = version === nothing ? "missing" : string(version)

function check_latest_core_packages(registry, tier, packages)
    latest_versions = latest_registered_versions(registry, CORE_PACKAGE_NAMES)
    manifest_versions = resolved_versions(CORE_PACKAGE_NAMES)
    results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, manifest_versions)

    println()
    println("Core package freshness check:")
    for result in results
        status = result.ok ? "ok" : "stale"
        println(
            "  $(result.package): resolved $(version_label(result.resolved)); ",
            "latest installable registered $(version_label(result.latest)) [$status]",
        )
    end

    all(result -> result.ok, results) && return

    println()
    println("Ecosystem canary resolved an older core package version for $tier.")
    println("This usually means a downstream compat bound still excludes the latest registered release.")
    println("Compatibility matrix for this tier:")
    print_compat_matrix(unique(vcat(CORE_PACKAGE_NAMES, packages)))
    exit(1)
end

function resolve_packages(tier, packages)
    println("Ecosystem canary tier: $tier")
    println("Packages: $(join(packages, ", "))")
    Pkg.activate(; temp = true)
    registry = ensure_general_registry()
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
    check_latest_core_packages(registry, tier, packages)
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
