function Base.convert(::Type{<:Qubist}, model::BQPJSON{BoolDomain})
    convert(Qubist{SpinDomain}, convert(BQPJSON{SpinDomain}, model))
end

function Base.convert(::Type{<:Qubist}, model::BQPJSON{SpinDomain})
    backend = copy(QUBOTools.backend(model))
    sites = if isempty(QUBOTools.variable_map(backend))
        0
    else
        1 + maximum(keys(QUBOTools.variable_map(backend)))
    end
    lines = length(QUBOTools.linear_terms(backend)) + length(QUBOTools.quadratic_terms(backend))

    Qubist{SpinDomain}(
        backend;
        sites=sites,
        lines=lines
    )
end

function QUBOTools.__isvalidbridge(
    source::BQPJSON{SpinDomain},
    target::BQPJSON{SpinDomain},
    ::Type{<:Qubist};
    kws...
)
    QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
end

function Base.convert(::Type{<:BQPJSON{BoolDomain}}, model::Qubist)
    convert(BQPJSON{BoolDomain}, convert(BQPJSON{SpinDomain}, model))
end

function Base.convert(::Type{<:BQPJSON{SpinDomain}}, model::Qubist)
    backend = copy(QUBOTools.backend(model))
    solutions = nothing

    BQPJSON{SpinDomain}(backend; solutions=solutions)
end

function QUBOTools.__isvalidbridge(
    source::Qubist{SpinDomain},
    target::Qubist{SpinDomain},
    ::Type{<:BQPJSON{SpinDomain}};
    kws...
)
    QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
end