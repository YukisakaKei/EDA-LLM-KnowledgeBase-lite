# Finds all clock ports of a hierarchical instance by tracing from sequential cells upward

proc get_hinst_clock_ports {hinst_name} {
    # Validate that the hierarchical instance exists
    set hinst_obj [get_db hinst:$hinst_name]
    if {$hinst_obj eq ""} {
        puts "ERROR: hinst $hinst_name not found"
        return
    }

    set result {}
    set seen [dict create]

    # Step 1: get all sequential insts inside this hinst
    set seq_insts [get_db $hinst_obj .insts -if {.is_sequential}]
    puts "DEBUG: found [llength $seq_insts] sequential insts"

    foreach inst $seq_insts {
        # Step 2: get clock pins of each sequential inst
        foreach pin [get_db $inst .pins -if {.is_clock}] {
            set clocks [get_db $pin .clocks]
            if {$clocks eq ""} { continue }

            # Step 3: trace pin.net -> net.hnets -> hnet drivers/loads (which include hports)
            set net [get_db $pin .net]
            foreach hnet [get_db $net .hnets] {
                foreach obj [concat [get_db $hnet .drivers] [get_db $hnet .loads]] {
                    if {[get_db $obj .obj_type] ne "hport"} { continue }
                    if {[get_db $obj .hinst] ne $hinst_obj} { continue }

                    foreach clk $clocks {
                        set clk_name  [get_db $clk  .name]
                        set hport_name [get_db $obj .name]
                        set key "$hport_name|$clk_name"
                        if {![dict exists $seen $key]} {
                            dict set seen $key 1
                            lappend result [list $hport_name $clk_name]
                            puts "Port: $hport_name  Clock: $clk_name"
                        }
                    }
                }
            }
        }
    }

    return $result
}
