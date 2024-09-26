function Base.convert(::Type{BQPJSON{SpinDomain}}, model::QUBO)
    convert(BQPJSON{SpinDomain}, convert(BQPJSON{BoolDomain}, model))
end

function Base.convert(::Type{BQPJSON{BoolDomain}}, model::QUBO)
    backend = copy(model.backend)
    solutions = nothing

    return BQPJSON{BoolDomain}(backend; solutions=solutions)
end

function QUBOTools.__isvalidbridge(
    source::BQPJSON{BoolDomain},
    target::BQPJSON{BoolDomain},
    ::Type{<:QUBO{BoolDomain}};
    kws...
)
    return QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
end

function Base.convert(::Type{<:QUBO}, model::BQPJSON{SpinDomain})
    convert(QUBO{BoolDomain}, convert(BQPJSON{BoolDomain}, model))
end

function Base.convert(::Type{<:QUBO}, model::BQPJSON{BoolDomain})
    backend = copy(model.backend)
    max_index = if isempty(QUBOTools.variable_map(backend))
        0
    else
        1 + maximum(keys(QUBOTools.variable_map(backend)))
    end
    num_diagonals = length(QUBOTools.linear_terms(backend))
    num_elements = length(QUBOTools.quadratic_terms(backend))

    return QUBO{BoolDomain}(
        backend;
        max_index=max_index,
        num_diagonals=num_diagonals,
        num_elements=num_elements
    )
end

function QUBOTools.__isvalidbridge(
    source::QUBO{BoolDomain},
    target::QUBO{BoolDomain},
    ::Type{<:BQPJSON{BoolDomain}};
    kws...
)
    return QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
end