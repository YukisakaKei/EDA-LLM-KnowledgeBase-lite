proc getConnectedBufInvNetLength {pinName} {

    # Initialize total length
    set total_length 0

    # Get all fanout instances from the specified pin
    set fanout_insts [all_fanout -from $pinName -only_cells]

    # Filter to get only buffer and inverter cells
    set buf_inv_insts [filter_collection $fanout_insts {is_buffer == true || is_inverter == true}]

    # Extract instance names from the filtered collection
    set inst_names [get_property $buf_inv_insts full_name]

    # Iterate through each buffer/inverter instance name
    foreach inst_name $inst_names {

        # Convert from get_* system pointer to dbGet system pointer using instance name
        set inst_ptr [dbGet top.insts.name $inst_name -p]

        # Get all output pins of this instance
        set output_pins [dbGet $inst_ptr.instTerms {.isOutput == 1}]

        foreach output_pin $output_pins {

            # Get the net connected to this output pin
            set output_net [dbGet $output_pin.net]

            # Calculate the total length of this net
            set net_length 0
            set wires [dbGet $output_net.wires]
            foreach wire $wires {
                set wire_length [dbGet $wire.length]
                set net_length [expr $net_length + $wire_length]
            }

            # Accumulate the total length
            set total_length [expr $total_length + $net_length]
        }
    }

    # Return the total length
    return $total_length
}

proc getPatternPinNetLengthStats {pinPattern {excludePattern ""}} {

    # Get all pins matching the pattern using dbGet
    set matched_pins [dbGet top.insts.instTerms.name $pinPattern -p]

    if {[llength $matched_pins] == 0} {
        puts "Warning: No pins matched pattern '$pinPattern'"
        return {}
    }

    # Filter out excluded pins if excludePattern is provided
    if {$excludePattern != ""} {
        set excluded_pins [dbGet top.insts.instTerms.name $excludePattern -p]
        set filtered_pins {}
        foreach pin_ptr $matched_pins {
            if {[lsearch $excluded_pins $pin_ptr] == -1} {
                lappend filtered_pins $pin_ptr
            }
        }
        set matched_pins $filtered_pins

        if {[llength $matched_pins] == 0} {
            puts "Warning: All pins were excluded by pattern '$excludePattern'"
            return {}
        }
    }

    # Initialize list to store net lengths
    set net_lengths {}

    # Iterate through each matched pin
    foreach pin_ptr $matched_pins {
        set pin_name [dbGet $pin_ptr.name]
        set net_length [getConnectedBufInvNetLength $pin_name]
        lappend net_lengths $net_length
    }

    # Calculate statistics
    set count [llength $net_lengths]
    set max_length [lindex [lsort -real $net_lengths] end]
    set min_length [lindex [lsort -real $net_lengths] 0]

    # Calculate average
    set sum 0
    foreach length $net_lengths {
        set sum [expr $sum + $length]
    }
    set avg_length [expr {$sum / double($count)}]

    # Calculate standard deviation
    set variance_sum 0
    foreach length $net_lengths {
        set diff [expr $length - $avg_length]
        set variance_sum [expr $variance_sum + $diff * $diff]
    }
    set variance [expr {$variance_sum / double($count)}]
    set std_dev [expr {sqrt($variance)}]

    # Return results as a dictionary
    return [dict create \
        count $count \
        max $max_length \
        min $min_length \
        avg $avg_length \
        std_dev $std_dev]
}
