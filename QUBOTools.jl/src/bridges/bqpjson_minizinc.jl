function Base.convert(::Type{<:MiniZinc}, model::BQPJSON{D}) where {D<:VariableDomain}
    convert(MiniZinc{D}, model)
end

function Base.convert(::Type{<:MiniZinc{B}}, model::BQPJSON{A}) where {A <: VariableDomain,B<:VariableDomain}
    convert(MiniZinc{B}, convert(BQPJSON{B}, model))
end

function Base.convert(::Type{<:MiniZinc{D}}, model::BQPJSON{D}) where {D<:VariableDomain}
    backend = copy(model.backend)

    MiniZinc{D}(backend)
end

function Base.convert(::Type{<:BQPJSON}, model::MiniZinc{D}) where {D<:VariableDomain}
    convert(BQPJSON{D}, model)
end

function Base.convert(::Type{<:BQPJSON{B}}, model::MiniZinc{A}) where {A <: VariableDomain,B<:VariableDomain}
    convert(BQPJSON{B}, convert(MiniZinc{B}, model))
end

function Base.convert(::Type{<:BQPJSON{D}}, model::MiniZinc{D}) where {D<:VariableDomain}
    backend = copy(model.backend)
    solutions = nothing

    BQPJSON{D}(backend, solutions)
end