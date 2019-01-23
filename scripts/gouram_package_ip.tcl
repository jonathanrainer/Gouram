# Get the directory where this script resides
set thisDir [file dirname [info script]]
set workDir [file join $thisDir .. work]

# Set up folders to be refered to later
set rtlRoot [file join $thisDir .. rtl]
set includeRoot [file join $thisDir .. include]

# Set up list of Gouram RTL files
set rtlFiles {
	ex_tracker.sv
	gouram.sv
	if_tracker.sv
	signal_tracker.sv
	trace_buffer.sv
	gouram.sv
	gouram_wrapper.v
	signal_tracker_if.sv
}

set includeFiles {
	gouram_datatypes.sv
	gouram_config.sv
}

# Create the directories to package the IP
if {![file exists [file join $workDir cip]]} {
    file mkdir [file join $workDir cip]
}
if {![file exists [file join $workDir cip Gouram]]} {
    file mkdir [file join $workDir cip Gouram]
}
if {![file exists [file join $workDir cip Gouram rtl]]} {
    file mkdir [file join $workDir cip Gouram rtl]
}
if {![file exists [file join $workDir cip Gouram include]]} {
    file mkdir [file join $workDir cip Gouram include]
}

set rtlFilesFull {}
set includeFilesFull {}

# Copy the files into each folder
foreach f $rtlFiles {
    file copy -force [file join $rtlRoot $f] [file join $workDir cip Gouram rtl]
    lappend rtlFilesFull [file join $workDir cip Gouram rtl $f]
}
foreach f $includeFiles {
    file copy -force [file join $includeRoot $f] [file join $workDir cip Gouram include]
    lappend includeFilesFull [file join $workDir cip Gouram include $f]
}

# Create project 
create_project -part xc7vx485tffg1761-2  -force Gouram [file join $workDir]
add_files -norecurse $rtlFilesFull
add_files -norecurse $includeFilesFull

update_compile_order -fileset sources_1

ipx::package_project -root_dir [file join $workDir cip Gouram] -vendor "jonathan-rainer.com" -library Kuuga
