QUBOTools.backend(model::BQPJSON) = model.backend
QUBOTools.model_name(::BQPJSON) = "BQPJSON"

function QUBOTools.version(model::BQPJSON)
    version = QUBOTools.version(QUBOTools.backend(model))

    if !isnothing(version)
        return version
    else
        return BQPJSON_VERSION_LATEST
    end
end

function QUBOTools.__isvalidbridge(
    source::BQPJSON{B},
    target::BQPJSON{B},
    ::Type{<:BQPJSON{A}};
    kws...
) where {A,B}
    flag = true

    if QUBOTools.id(source) != QUBOTools.id(target)
        @error "Test Failure: ID mismatch"
        flag = false
    end

    if QUBOTools.version(source) != QUBOTools.version(target)
        @error "Test Failure: Version mismatch"
        flag = false
    end

    if QUBOTools.description(source) != QUBOTools.description(target)
        @error "Test Failure: Description mismatch"
        flag = false
    end

    if QUBOTools.metadata(source) != QUBOTools.metadata(target)
        @error "Test Failure: Inconsistent metadata"
        flag = false
    end

    # TODO: How to compare them?
    # if source.solutions != target.solutions
    #     @error "Test Failure: Inconsistent solutions"
    #     flag = false
    # end

    if !QUBOTools.__isvalidbridge(
        QUBOTools.backend(source),
        QUBOTools.backend(target);
        kws...
    )
        flag = false
    end

    return flag
end