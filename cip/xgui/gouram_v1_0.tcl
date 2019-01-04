# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DATA_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INSTR_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INSTR_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TRACE_BUFFER_SIZE" -parent ${Page_0}


}

proc update_PARAM_VALUE.DATA_ADDR_WIDTH { PARAM_VALUE.DATA_ADDR_WIDTH } {
	# Procedure called to update DATA_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_ADDR_WIDTH { PARAM_VALUE.DATA_ADDR_WIDTH } {
	# Procedure called to validate DATA_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.INSTR_ADDR_WIDTH { PARAM_VALUE.INSTR_ADDR_WIDTH } {
	# Procedure called to update INSTR_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INSTR_ADDR_WIDTH { PARAM_VALUE.INSTR_ADDR_WIDTH } {
	# Procedure called to validate INSTR_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.INSTR_DATA_WIDTH { PARAM_VALUE.INSTR_DATA_WIDTH } {
	# Procedure called to update INSTR_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INSTR_DATA_WIDTH { PARAM_VALUE.INSTR_DATA_WIDTH } {
	# Procedure called to validate INSTR_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.TRACE_BUFFER_SIZE { PARAM_VALUE.TRACE_BUFFER_SIZE } {
	# Procedure called to update TRACE_BUFFER_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TRACE_BUFFER_SIZE { PARAM_VALUE.TRACE_BUFFER_SIZE } {
	# Procedure called to validate TRACE_BUFFER_SIZE
	return true
}


proc update_MODELPARAM_VALUE.INSTR_ADDR_WIDTH { MODELPARAM_VALUE.INSTR_ADDR_WIDTH PARAM_VALUE.INSTR_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INSTR_ADDR_WIDTH}] ${MODELPARAM_VALUE.INSTR_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.INSTR_DATA_WIDTH { MODELPARAM_VALUE.INSTR_DATA_WIDTH PARAM_VALUE.INSTR_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INSTR_DATA_WIDTH}] ${MODELPARAM_VALUE.INSTR_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.DATA_ADDR_WIDTH { MODELPARAM_VALUE.DATA_ADDR_WIDTH PARAM_VALUE.DATA_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_ADDR_WIDTH}] ${MODELPARAM_VALUE.DATA_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.TRACE_BUFFER_SIZE { MODELPARAM_VALUE.TRACE_BUFFER_SIZE PARAM_VALUE.TRACE_BUFFER_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TRACE_BUFFER_SIZE}] ${MODELPARAM_VALUE.TRACE_BUFFER_SIZE}
}

