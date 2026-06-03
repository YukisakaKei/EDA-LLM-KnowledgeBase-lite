# Calculates the total wiring length of all buffer/inverter output nets

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
