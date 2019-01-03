# Get the directory where this script resides
set thisDir [file dirname [info script]]
set workDir [file join $thisDir .. work]

# Set up folders to be refered to later
set rtlRoot [file join $thisDir .. rtl]
set includeRoot [file join $thisDir .. include]

# Set up list of RTL files
set rtlFiles {
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
    godai_wrapper.v
}

set includeFiles {
    godai_defines.sv
    riscv_config.sv
    riscv_defines.sv 
}

# Create the directories to package the IP
if {![file exists [file join $workDir cip]]} {
    file mkdir [file join $workDir cip]
}
if {![file exists [file join $workDir cip Godai]]} {
    file mkdir [file join $workDir cip Godai]
}
if {![file exists [file join $workDir cip Godai rtl]]} {
    file mkdir [file join $workDir cip Godai rtl]
}
if {![file exists [file join $workDir cip Godai include]]} {
    file mkdir [file join $workDir cip Godai include]
}

set rtlFilesFull {}
set includeFilesFull {}

# Copy the files into each folder
foreach f $rtlFiles {
    file copy -force [file join $rtlRoot $f] [file join $workDir cip Godai rtl]
    lappend rtlFilesFull [file join $workDir cip Godai rtl $f]
}
foreach f $includeFiles {
    file copy -force [file join $includeRoot $f] [file join $workDir cip Godai include]
    lappend includeFilesFull [file join $workDir cip Godai include $f]
}

# Create project 
create_project -part xc7vx485tffg1761-2  -force Godai [file join $workDir]
add_files -norecurse $rtlFilesFull
add_files -norecurse $includeFilesFull

update_compile_order -fileset sources_1

ipx::package_project -root_dir [file join $workDir cip Godai] -vendor "jonathan-rainer.com" -library Kuuga
