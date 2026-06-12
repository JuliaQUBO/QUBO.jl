#!/usr/bin/env julia

using Pkg

const JULIA_UUID = Base.UUID("1222c4b2-2114-5bfd-aeef-88e4692bbb3e")
const WATCHED_DEPS = ["julia", "QUBODrivers", "QUBOTools", "ToQUBO"]

function ensure_general_registry()
    registries = Pkg.Registry.reachable_registries()
    if isempty(registries)
        Pkg.Registry.add("General")
        registries = Pkg.Registry.reachable_registries()
    else
        Pkg.Registry.update()
        registries = Pkg.Registry.reachable_registries()
    end
    matches = filter(registry -> registry.name == "General", registries)
    isempty(matches) && error("General registry is not available")
    return only(matches)
end

function package_maps(registry)
    uuid_by_name = Dict{String,Base.UUID}()
    name_by_uuid = Dict{Base.UUID,String}()
    for (uuid, entry) in registry.pkgs
        uuid_by_name[entry.name] = uuid
        name_by_uuid[uuid] = entry.name
    end
    name_by_uuid[JULIA_UUID] = "julia"
    return uuid_by_name, name_by_uuid
end

function latest_compat(registry, uuid::Base.UUID)
    info = Pkg.Registry.registry_info(registry.pkgs[uuid])
    latest = maximum(keys(info.version_info))
    compat_by_version = Pkg.Registry.compat_info(info)
    compat = get(compat_by_version, latest, Dict{Base.UUID,Pkg.Types.VersionSpec}())
    return latest, compat
end

function compat_string(compat, dep_uuid)
    spec = get(compat, dep_uuid, nothing)
    spec === nothing && return "-"
    return string(spec)
end

function print_matrix(packages)
    registry = ensure_general_registry()
    uuid_by_name, _ = package_maps(registry)
    watched = Pair{String,Base.UUID}[]
    for dep in WATCHED_DEPS
        if dep == "julia"
            push!(watched, dep => JULIA_UUID)
        elseif haskey(uuid_by_name, dep)
            push!(watched, dep => uuid_by_name[dep])
        end
    end

    println("Registered ecosystem compatibility matrix")
    println("Registry: $(registry.name)")
    println()

    header = ["Package", "Latest", WATCHED_DEPS...]
    rows = Vector{Vector{String}}()
    for package in packages
        if !haskey(uuid_by_name, package)
            push!(rows, [package, "not registered", fill("-", length(WATCHED_DEPS))...])
            continue
        end
        latest, compat = latest_compat(registry, uuid_by_name[package])
        values = [compat_string(compat, dep_uuid) for (_, dep_uuid) in watched]
        push!(rows, [package, string(latest), values...])
    end

    widths = [max(length(header[i]), maximum(length(row[i]) for row in rows)) for i in eachindex(header)]

    function print_row(row)
        for (i, cell) in pairs(row)
            i > 1 && print("  ")
            print(rpad(cell, widths[i]))
        end
        println()
    end

    print_row(header)
    print_row([repeat("-", width) for width in widths])
    foreach(print_row, rows)
end

function main(args)
    packages = isempty(args) ? ["QUBO"] : args
    print_matrix(packages)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
