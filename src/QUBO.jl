module QUBO

import JuMP
import MathOptInterface as MOI

# QUBOTools
import QUBOTools
import QUBOTools: ↑, ↓
import QUBOTools: reads

const QUBOTools_MOI = Base.get_extension(QUBOTools, :QUBOTools_MOI)
const Spin          = QUBOTools_MOI.Spin
const NumberOfReads = QUBOTools_MOI.NumberOfReads

export QUBOTools
export ↑, ↓
export reads
export Spin, NumberOfReads

# QUBODrivers
import QUBODrivers
import QUBODrivers: ExactSampler, IdentitySampler, RandomSampler

export QUBODrivers
export ExactSampler, IdentitySampler, RandomSampler

# ToQUBO
import ToQUBO
export ToQUBO

include("wrapper.jl")

function source_model(model::JuMP.Model)
    return JuMP.get_attribute(model, ToQUBO.Attributes.SourceModel())
end

function target_model(model::JuMP.Model)
    return JuMP.get_attribute(model, ToQUBO.Attributes.TargetModel())
end

end # module QUBO
