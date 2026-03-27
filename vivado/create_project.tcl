# ============================================================================
# Vivado Project Creation Script for SRAM-PUF System (Simplified)
# ============================================================================

set project_name "sram_puf_project"
set project_dir "./vivado_project"

# Create project for Artix-7 35T
create_project $project_name $project_dir -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Get project root directory
set script_dir [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]

# Add RTL source files (no bch_codec)
add_files -norecurse [list \
    [file join $project_root rtl sram_puf_params.vh] \
    [file join $project_root rtl sram_puf_core.v] \
    [file join $project_root rtl hamming_codec.v] \
    [file join $project_root rtl sha256_core.v] \
    [file join $project_root rtl key_gen.v] \
    [file join $project_root rtl fuzzy_extractor.v] \
    [file join $project_root rtl sram_puf_controller.v] \
]

# Add testbench
add_files -fileset sim_1 -norecurse [list \
    [file join $project_root tb tb_sram_puf_top.v] \
]

# Add constraints
add_files -fileset constrs_1 -norecurse [list \
    [file join $script_dir constraints.xdc] \
]

# Set top modules
set_property top sram_puf_controller [current_fileset]
set_property top tb_sram_puf_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "========================================="
puts "Project created successfully!"
puts "Next: launch_simulation → run all"
puts "========================================="
