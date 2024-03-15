module QUBO

import JuMP
import MathOptInterface as MOI

# QUBOTools
import QUBOTools
import QUBOTools: ↑, ↓
import QUBOTools: reads
import QUBOTools: __moi_spin_set, __moi_num_reads

const Spin          = QUBOTools.__moi_spin_set()
const NumberOfReads = QUBOTools.__moi_num_reads()

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

end # module QUBO
