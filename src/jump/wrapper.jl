# Spin Variable for JuMP
# Ref: https://jump.dev/JuMP.jl/stable/developers/extensions/#extend_variable_macro

struct SpinInfo
    info::JuMP.VariableInfo
end

function JuMP.build_variable(::Function, info::JuMP.VariableInfo, ::Type{Spin}; kwargs...)
    return SpinInfo(info)
end

function JuMP.add_variable(model::JuMP.Model, info::SpinInfo, name::String)
    x = JuMP.add_variable(model, JuMP.ScalarVariable(info.info), name)

    JuMP.@constraint(model, x ∈ Spin())

    return x
end

JuMP.in_set_string(::MIME"text/plain", ::Spin) = "spin"
JuMP.in_set_string(::MIME"text/latex", ::Spin) = raw"\in \left\langle{-1, 1}\right\rangle"
