# Script to get library file paths for all memory instances in the design
# Usage: source get_mem_lib_paths.tcl

# Filter pattern for library paths (set to empty string "" to show all libraries)
# Example: set path_filter "tt0p75v85c" to only show libraries with "tt0p75v85c" in path
set path_filter ""

puts "========================================="
puts "Searching for memory libraries in design"
if {$path_filter != ""} {
    puts "Path filter: *${path_filter}*"
}
puts "========================================="

# Step 1: Get all memory instances using dbGet
# Memory instances have cell.subClass = "block"
set mem_insts [dbGet top.insts.cell.subClass block -p2]

if {$mem_insts == "" || $mem_insts == "0x0"} {
    puts "\nWarning: No memory instances found (cell.subClass = block)"
    exit
}

puts "\nFound [llength $mem_insts] memory instances in design"

# Collect memory cell names and LEF file paths
set mem_cell_names [dbGet $mem_insts.cell.name -u]
set mem_lef_files [dbGet $mem_insts.cell.lefFileName -u]

# Step 2: Convert to get_cells collection for compatibility with get_property
set mem_inst_names [dbGet $mem_insts.name]
set mem_cells [get_cells $mem_inst_names]

# Step 3: Get the library cells corresponding to these instances
set mem_lib_cells [get_lib_cells -of_objects $mem_cells]

# Step 4: Get the libraries that contain these library cells
set mem_libs [get_libs -of_objects $mem_lib_cells]

# Step 5: Process each library and output library paths
# Use a list to track processed libraries and avoid duplicates
set processed_libs [list]
set all_lib_paths [list]
set lib_count 0

foreach_in_collection lib $mem_libs {
    set lib_name [get_property $lib hierarchical_name]

    # Skip if already processed
    if {[lsearch $processed_libs $lib_name] != -1} {
        continue
    }

    # Get the full file path of the library
    # source_file_name returns a list of all library paths across all analysis views
    set lib_paths [get_property $lib source_file_name]

    # Apply path filter if specified
    if {$path_filter != ""} {
        set filtered_paths [list]
        foreach path $lib_paths {
            if {[string match "*${path_filter}*" $path]} {
                lappend filtered_paths $path
            }
        }
        # Skip this library if no paths match the filter
        if {[llength $filtered_paths] == 0} {
            continue
        }
        set lib_paths $filtered_paths
    }

    lappend processed_libs $lib_name
    incr lib_count

    # Store paths for later output
    set all_lib_paths [concat $all_lib_paths $lib_paths]

    puts "\n========================================="
    puts "Memory Library #$lib_count: $lib_name"
    puts "  Library Paths:"
    foreach path $lib_paths {
        puts "    $path"
    }
}

puts "\n========================================="
puts "Summary:"
puts "  Total memory instances found: [llength $mem_insts]"
puts "  Total unique libraries: $lib_count"
puts "========================================="

# Remove duplicates and output all paths for easy copying
set all_lib_paths [lsort -unique $all_lib_paths]

puts "\n========================================="
puts "All Library Paths (for copying):"
puts "========================================="
foreach path $all_lib_paths {
    puts "$path \\"
}

puts "\n========================================="
puts "Memory Cell Names:"
puts "========================================="
foreach cell_name $mem_cell_names {
    puts "$cell_name"
}

puts "\n========================================="
puts "LEF File Paths (for copying):"
puts "========================================="
foreach lef_file $mem_lef_files {
    puts "$lef_file \\"
}
puts ""
