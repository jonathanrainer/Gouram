# Get the directory where this script resides
set thisDir 	[file dirname [info script]]
set workDir 	[file join $thisDir .. work]
set godaiDir 	[file join $thisDir .. .. Godai]

# Set up folders to be refered to later
set gouramRTLRoot [file join $thisDir .. rtl]
set gouramIncludeRoot [file join $thisDir .. include]
set godaiRTLRoot [file join $godaiDir rtl]
set godaiIncludeRoot [file join $godaiDir include]

# Set up list of Gouram RTL files
set gouramRTLFiles {
	advanced_signal_tracker.sv
	ex_tracker.sv
	gouram.sv
	id_tracker.sv
	if_tracker.sv
	signal_tracker.sv
	trace_buffer.sv
	wb_tracker.sv
}

# Set up list of Godai RTL files
set godaiRTLFiles {
    alu.sv
    alu_div.sv
    cluster_clock_gating.sv
    compressed_decoder.sv
    controller.sv
    cs_registers.sv
    debug_unit.sv
    decoder.sv
    exc_controller.sv
    ex_stage.sv
    hwloop_controller.sv
    hwloop_regs.sv
    id_stage.sv
    if_stage.sv
    load_store_unit.sv
    mult.sv
    prefetch_buffer.sv
    register_file_ff.sv
    riscv_core.sv
}

# Set up list of Godai Include files
set godaiIncludeFiles {
    riscv_config.sv
    riscv_defines.sv 
}

set rtlFilesFull {}

foreach f $gouramRTLFiles {
    lappend rtlFilesFull [file join $gouramRTLRoot $f]
}

set simOnlyFiles {}
lappend simOnlyFiles [file join $thisDir .. tb system gouram_testbench.sv]
lappend simOnlyFiles [file join $thisDir .. tb system instruction_memory_mock.sv]
lappend simOnlyFiles [file join $thisDir .. tb system data_memory_mock.sv]

foreach f $godaiRTLFiles {
	lappend simOnlyFiles [file join $godaiRTLRoot $f]
}

foreach f $godaiIncludeFiles {
	lappend simOnlyFiles [file join $godaiIncludeRoot $f]
}

# Create project 
create_project -part xc7vx485tffg1761-2  -force Gouram [file join $workDir]
add_files -norecurse $rtlFilesFull
add_files -fileset sim_1 $simOnlyFiles
set_property top gouram_testbench [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
