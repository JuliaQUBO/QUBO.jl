const MINIZINC_BACKEND_TYPE{D} = StandardQUBOModel{Int,Int,Float64,D}
const MINIZINC_VAR_SYMBOL = "x"
const MINIZINC_RE_COMMENT = r"^%(\s*.*)?$"
const MINIZINC_RE_METADATA = r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*(.+)$"
const MINIZINC_RE_DOMAIN = r"^set of int\s*:\s*Domain\s*=\s*\{\s*([+-]?[0-9]+)\s*,\s*([+-]?[0-9]+)\s*\}\s*;$"
const MINIZINC_RE_FACTOR = r"^float\s*:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*([+-]?([0-9]*[.])?[0-9]+)\s*;$"
const MINIZINC_RE_VARIABLE = r"^var\s+Domain\s*:\s*" * MINIZINC_VAR_SYMBOL * r"([0-9]+)\s*;$"
const MINIZINC_RE_OBJECTIVE = r"^var\s+float\s*:\s*objective\s*=\s*(.+);$"

function MINIZINC_DEFAULT_OFFSET end
MINIZINC_DEFAULT_OFFSET(::Nothing) = 0.0
MINIZINC_DEFAULT_OFFSET(offset::Float64) = offset
function MINIZINC_DEFAULT_SCALE end
MINIZINC_DEFAULT_SCALE(::Nothing) = 1.0
MINIZINC_DEFAULT_SCALE(scale::Float64) = scale

@doc raw"""
""" mutable struct MiniZinc{D<:VariableDomain} <: AbstractQUBOModel{D}
    backend::MINIZINC_BACKEND_TYPE{D}

    function MiniZinc{D}(backend::MINIZINC_BACKEND_TYPE{D}) where {D<:VariableDomain}
        new{D}(backend)
    end

    function MiniZinc{D}(
        linear_terms::Dict{Int,Float64},
        quadratic_terms::Dict{Tuple{Int,Int},Float64},
        variable_map::Dict{Int,Int},
        offset::Union{Float64,Nothing},
        scale::Union{Float64,Nothing},
        id::Union{Integer,Nothing},
        description::Union{String,Nothing},
        metadata::Union{Dict{String,Any},Nothing},
    ) where {D<:VariableDomain}
        backend = MINIZINC_BACKEND_TYPE{D}(
            linear_terms,
            quadratic_terms,
            variable_map;
            offset=offset,
            scale=scale,
            id=id,
            description=description,
            metadata=metadata
        )

        MiniZinc{D}(backend)
    end
end

function __isvalidbridge(
    source::MiniZinc{D},
    target::MiniZinc{D},
    ::Type{<:MiniZinc{D}};
    kws...
) where {D<:VariableDomain}
    QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
end

include("data.jl")
include("io.jl")