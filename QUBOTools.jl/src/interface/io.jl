# ~*~ I/O ~*~ #
function Base.read(::IO, M::Type{<:AbstractQUBOModel})
    QUBOTools.codec_error("'Base.read' not implemented for model of type '$(M)'")
end

function Base.read(path::AbstractString, M::Type{<:AbstractQUBOModel})
    open(path, "r") do io
        return read(io, M)
    end
end

function Base.write(::IO, model::AbstractQUBOModel)
    QUBOTools.codec_error("'Base.write' not implemented for model of type '$(typeof(model))'")
end

function Base.write(path::AbstractString, model::AbstractQUBOModel)
    open(path, "w") do io
        return write(io, model)
    end
end

function Base.convert(::Type{Y}, ::X) where {X <: AbstractQUBOModel, Y<:AbstractQUBOModel}
    QUBOTools.codec_error("'Base.convert' not implemented for turning model of type '$(X)' into '$(Y)'")
end

function Base.convert(::Type{M}, model::M) where {M<:AbstractQUBOModel}
    model # Short-circuit! Yeah!
end

function Base.copy!(::M, ::M) where {M<:AbstractQUBOModel}
    QUBOTools.codec_error("'Base.copy!' not implemented for copying '$M' models in-place")
end

function Base.copy!(
    target::X,
    source::Y,
) where {X<:AbstractQUBOModel,Y<:AbstractQUBOModel}
    copy!(target, convert(X, source))
end