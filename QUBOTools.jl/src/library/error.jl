struct QUBOCodecError <: Exception
    msg::Union{String,Nothing}

    function QUBOCodecError(msg::Union{String,Nothing}=nothing)
        new(msg)
    end
end

function Base.showerror(io::IO, e::QUBOCodecError)
    if isnothing(e.msg)
        print(io, "QUBO Codec Error")
    else
        print(io, "QUBO Codec Error: $(e.msg)")
    end
end

function codec_error(msg::Union{String,Nothing}=nothing)
    throw(QUBOCodecError(msg))
end

struct SampleError <: Exception
    msg::Union{String,Nothing}

    function SampleError(msg::Union{String,Nothing}=nothing)
        new(msg)
    end
end

function Base.showerror(io::IO, e::SampleError)
    if isnothing(e.msg)
        print(io, "Sample Error")
    else
        print(io, "Sample Error: $(e.msg)")
    end
end

function sample_error(msg::Union{String,Nothing}=nothing)
    throw(SampleError(msg))
end