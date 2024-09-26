QUBOTools.backend(model::HFS) = model.backend
QUBOTools.model_name(::HFS) = "HFS"

@doc raw"""
""" function chimera_cell_size end

QUBOTools.chimera_cell_size(model::HFS) = model.chimera.cell_size

@doc raw"""
""" function chimera_precision end

QUBOTools.chimera_precision(model::HFS) = model.chimera.precision