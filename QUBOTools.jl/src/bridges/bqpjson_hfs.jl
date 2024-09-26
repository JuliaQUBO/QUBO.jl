function Base.convert(::Type{HFS{BoolDomain}}, model::BQPJSON{BoolDomain}; kws...)
    backend = copy(QUBOTools.backend(model))
    chimera = Chimera(
        backend;
        kws...
    )

    return HFS{BoolDomain}(backend, chimera)
end