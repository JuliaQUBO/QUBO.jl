const BQPJSON_SCHEMA          = JSONSchema.Schema(JSON.parsefile(joinpath(@__DIR__, "bqpjson.schema.json")))
const BQPJSON_VERSION_LIST    = VersionNumber[v"1.0.0"]
const BQPJSON_VERSION_LATEST  = BQPJSON_VERSION_LIST[end]
const BQPJSON_BACKEND_TYPE{D} = StandardQUBOModel{Int,Int,Float64,D}

BQPJSON_VARIABLE_DOMAIN(::Type{<:BoolDomain}) = "boolean"
BQPJSON_VARIABLE_DOMAIN(::Type{<:SpinDomain}) = "spin"

BQPJSON_VALIDATE_DOMAIN(x::Integer, ::Type{<:BoolDomain}) = x == 0 || x == 1
BQPJSON_VALIDATE_DOMAIN(s::Integer, ::Type{<:SpinDomain}) = s == -1 || s == 1

BQPJSON_SWAP_DOMAIN(x::Integer, ::Type{<:BoolDomain}) = (x == 1 ? 1 : -1)
BQPJSON_SWAP_DOMAIN(s::Integer, ::Type{<:SpinDomain}) = (s == 1 ? 1 : 0)

@doc raw"""
    BQPJSON{D}(
        backend::BQPJSON_BACKEND_TYPE{D},
        solutions::Union{Vector,Nothing},
    ) where {D<:VariableDomain}

### References
[1] https://BQPJSON.readthedocs.io
""" mutable struct BQPJSON{D<:VariableDomain} <: AbstractQUBOModel{D}
    backend::BQPJSON_BACKEND_TYPE{D}
    solutions::Union{Vector,Nothing}

    function BQPJSON{D}(
        backend::BQPJSON_BACKEND_TYPE{D};
        solutions::Union{Vector,Nothing}=nothing
    ) where {D<:VariableDomain}
        new{D}(backend, solutions)
    end

    function BQPJSON{D}(
        linear_terms::Dict{Int,Float64},
        quadratic_terms::Dict{Tuple{Int,Int},Float64};
        solutions::Union{Vector,Nothing}=nothing,
        kws...
    ) where {D<:VariableDomain}
        backend = BQPJSON_BACKEND_TYPE{D}(
            linear_terms,
            quadratic_terms;
            kws...
        )

        BQPJSON{D}(backend; solutions=solutions)
    end
end

include("data.jl")
include("io.jl")