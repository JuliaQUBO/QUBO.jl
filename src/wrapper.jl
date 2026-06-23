# Spin Variable for JuMP
# Ref: https://jump.dev/JuMP.jl/stable/developers/extensions/#extend_variable_macro

struct SpinInfo
    info::JuMP.VariableInfo
end

function JuMP.build_variable(::Function, info::JuMP.VariableInfo, ::Type{Spin}; kwargs...)
    return SpinInfo(info)
end

function JuMP.add_variable(model::JuMP.Model, spin_info::SpinInfo, name::String)
    x = JuMP.add_variable(model, JuMP.ScalarVariable(spin_info.info), name)

    JuMP.@constraint(model, x ∈ Spin())

    return x
end

JuMP.in_set_string(::MIME"text/plain", ::Spin) = "spin"
JuMP.in_set_string(::MIME"text/latex", ::Spin) = raw"\in \left\langle{-1, 1}\right\rangle"

# Number of Reads
@doc raw"""
    reads(model::JuMP.Model; result::Integer = 1)

Returns the multiplicity of a given result.
"""
function QUBOTools.reads(model::JuMP.Model; result::Integer = 1)
    return JuMP.get_attribute(model, NumberOfReads(result))::Integer
end

# QUBOTools backend for JuMP models using ToQUBO. ToQUBO v0.5+ owns this
# extension method; keep the local shim only for older compatible releases.
if !hasmethod(QUBOTools.backend, Tuple{JuMP.Model})
    function QUBOTools.backend(model::JuMP.Model)
        return QUBOTools.backend(JuMP.unsafe_backend(model))
    end
end
