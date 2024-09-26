const QUBO_BACKEND_TYPE{D} = StandardQUBOModel{Int,Int,Float64,D}

@doc raw"""
""" mutable struct QUBO{D<:BoolDomain} <: AbstractQUBOModel{D}
    backend::QUBO_BACKEND_TYPE{D}
    max_index::Int
    num_diagonals::Int
    num_elements::Int

    function QUBO{D}(
        backend::QUBO_BACKEND_TYPE{D};
        max_index::Integer,
        num_diagonals::Integer,
        num_elements::Integer,
    ) where {D}

        new{D}(
            backend,
            max_index,
            num_diagonals,
            num_elements,
        )
    end

    function QUBO{D}(
        linear_terms::Dict{Int,Float64},
        quadratic_terms::Dict{Tuple{Int,Int},Float64};
        max_index::Integer,
        num_diagonals::Integer,
        num_elements::Integer,
        kws...
    ) where {D<:BoolDomain}
        backend = QUBO_BACKEND_TYPE{D}(linear_terms, quadratic_terms; kws...)

        QUBO{D}(
            backend,
            max_index=max_index,
            num_diagonals=num_diagonals,
            num_elements=num_elements,
        )
    end
end

function __isvalidbridge(
    source::QUBO{D},
    target::QUBO{D},
    ::Type{<:QUBO{D}};
    kws...
) where {D<:BoolDomain}
    flag = true

    if source.max_index != target.max_index
        @error "Test Failure: Inconsistent maximum index"
        flag = false
    end

    if source.num_diagonals != target.num_diagonals
        @error "Test Failure: Inconsistent number of diagonals"
        flag = false
    end

    if source.num_elements != target.num_elements
        @error "Test Failure: Inconsistent number of elements"
        flag = false
    end

    if !QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
        flag = false
    end

    return flag
end

include("data.jl")
include("io.jl")