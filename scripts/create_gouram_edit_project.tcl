# Get the directory where this script resides
set thisDir 	[file dirname [info script]]
set workDir 	[file join $thisDir .. work]
set godaiDir 	[file join $thisDir .. .. Godai]

# Set up folders to be refered to later
set gouramRTLRoot [file join $thisDir .. rtl]
set gouramIncludeRoot [file join $thisDir .. include]
set godaiRTLRoot [file join $godaiDir rtl]
set godaiIncludeRoot [file join $godaiDir include]

source [file join $thisDir gouram_manifest.tcl]
source [file join $godaiDir scripts godai_manifest.tcl]

set rtlFilesFull {}
set includeFilesFull {}

foreach f $GouramRTLFiles {
    lappend rtlFilesFull [file join $gouramRTLRoot $f]
}
foreach f $GouramIncludeFiles {
    lappend includeFilesFull [file join $gouramIncludeRoot $f]
}

set simOnlyFiles {}
lappend simOnlyFiles [file join $thisDir .. tb system gouram_testbench.sv]
lappend simOnlyFiles [file join $thisDir .. tb system instruction_memory_mock.sv]
lappend simOnlyFiles [file join $thisDir .. tb system data_memory_mock.sv]
lappend simOnlyFiles [file join $thisDir .. wcfg post_synth_config.wcfg]

foreach f $GodaiRTLFiles {
	lappend simOnlyFiles [file join $godaiRTLRoot $f]
}

foreach f $GodaiIncludeFiles {
	lappend simOnlyFiles [file join $godaiIncludeRoot $f]
}

# Create project 
create_project -part xc7vx485tffg1761-2  -force Gouram [file join $workDir]
add_files -norecurse $rtlFilesFull
add_files -norecurse $includeFilesFull

add_files -fileset sim_1 $simOnlyFiles
set_property top gouram_testbench [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
