# Create placement regions for registers related to top-level signal ports.
#
# Output ports:
#   Registers that launch timing paths to the port are collected with all_fanin.
#
# Input ports:
#   Registers that capture timing paths from the port are collected with all_fanout.
#   PG/clock/analog inputs are filtered by DB attributes before fanout tracing.
#   Any port can be excluded by passing exact port names to the main proc.
#
# Usage:
#   source create_all_port_reg_regions.tcl
#   create_all_port_reg_regions
#
# Optional distance controls:
#   create_all_port_reg_regions 200 20
#     200: side length of each port square, centered at port llx/lly
#      20: margin used to tighten the region edge along the port line
#
# Optional exact port exclusion:
#   create_all_port_reg_regions 200 20 {VDD VSS clk scan_en}
#
# Optional trace-through control:
#   create_all_port_reg_regions 200 20 {VDD VSS clk scan_en} all

proc _aprr_min2 {a b} {
    if {$a < $b} {
        return $a
    }
    return $b
}

proc _aprr_max2 {a b} {
    if {$a > $b} {
        return $a
    }
    return $b
}

proc _aprr_box_overlap {box_a box_b} {
    lassign $box_a ax1 ay1 ax2 ay2
    lassign $box_b bx1 by1 bx2 by2

    if {$ax1 > $bx2 || $bx1 > $ax2} {
        return 0
    }
    if {$ay1 > $by2 || $by1 > $ay2} {
        return 0
    }
    return 1
}

proc _aprr_box_union {boxes} {
    set first_box [lindex $boxes 0]
    lassign $first_box llx lly urx ury

    foreach box [lrange $boxes 1 end] {
        lassign $box x1 y1 x2 y2
        set llx [_aprr_min2 $llx $x1]
        set lly [_aprr_min2 $lly $y1]
        set urx [_aprr_max2 $urx $x2]
        set ury [_aprr_max2 $ury $y2]
    }

    return [list $llx $lly $urx $ury]
}

proc _aprr_same_coord {values} {
    if {[llength $values] <= 1} {
        return 1
    }

    set first_value [lindex $values 0]
    foreach value [lrange $values 1 end] {
        if {abs($value - $first_value) > 0.000001} {
            return 0
        }
    }
    return 1
}

proc _aprr_reset_warning_stats {} {
    upvar 1 _aprr_warn_counts warn_counts
    upvar 1 _aprr_warn_printed warn_printed
    upvar 1 _aprr_warning_order warning_order
    upvar 1 _aprr_warning_limit warning_limit
    upvar 1 _aprr_warning_log_file warning_log_file

    catch {unset warn_counts}
    catch {unset warn_printed}
    set warning_order [list]
    set warning_limit 5
    set warning_log_file [file join [pwd] create_all_port_reg_regions_debug.log]

    if {[catch {
        set log_fp [open $warning_log_file w]
        puts $log_fp "create_all_port_reg_regions warning debug log"
        puts $log_fp "All warnings are listed below without console suppression."
        close $log_fp
    } err_msg]} {
        puts "Warning: Cannot create warning debug log '$warning_log_file': $err_msg"
        set warning_log_file ""
    }
}

proc _aprr_warn {key message} {
    set state_level ""
    set max_level [expr {[info level] - 1}]
    for {set level 1} {$level <= $max_level} {incr level} {
        if {[uplevel $level {info exists _aprr_warning_order}]} {
            set state_level $level
            break
        }
    }

    if {$state_level eq ""} {
        puts "Warning: $message"
        return
    }

    upvar $state_level _aprr_warn_counts warn_counts
    upvar $state_level _aprr_warn_printed warn_printed
    upvar $state_level _aprr_warning_order warning_order
    upvar $state_level _aprr_warning_limit warning_limit
    upvar $state_level _aprr_warning_log_file warning_log_file

    if {![info exists warning_limit]} {
        set warning_limit 5
    }

    if {![info exists warn_counts($key)]} {
        set warn_counts($key) 0
        set warn_printed($key) 0
        lappend warning_order $key
    }

    incr warn_counts($key)

    if {[info exists warning_log_file] && $warning_log_file ne ""} {
        if {![catch {set log_fp [open $warning_log_file a]}]} {
            puts $log_fp "Warning: $key: $message"
            close $log_fp
        }
    }

    if {$warn_printed($key) < $warning_limit} {
        puts "Warning: $message"
        incr warn_printed($key)
    } elseif {$warn_printed($key) == $warning_limit} {
        puts "Warning: Further '$key' warnings suppressed."
        incr warn_printed($key)
    }
}

proc _aprr_print_warning_summary {} {
    set state_level ""
    set max_level [expr {[info level] - 1}]
    for {set level 1} {$level <= $max_level} {incr level} {
        if {[uplevel $level {info exists _aprr_warning_order}]} {
            set state_level $level
            break
        }
    }

    if {$state_level eq ""} {
        puts "Warnings: 0"
        return
    }

    upvar $state_level _aprr_warn_counts warn_counts
    upvar $state_level _aprr_warning_order warning_order
    upvar $state_level _aprr_warning_log_file warning_log_file

    if {![info exists warning_order] || [llength $warning_order] == 0} {
        puts "Warnings: 0"
        if {[info exists warning_log_file] && $warning_log_file ne ""} {
            if {![catch {set log_fp [open $warning_log_file a]}]} {
                puts $log_fp "Warnings: 0"
                close $log_fp
            }
        }
        return
    }

    puts "Warning summary:"
    if {[info exists warning_log_file] && $warning_log_file ne ""} {
        if {![catch {set log_fp [open $warning_log_file a]}]} {
            puts $log_fp "Warning summary:"
            foreach key $warning_order {
                puts $log_fp "  $key: $warn_counts($key)"
            }
            close $log_fp
        }
    }
    foreach key $warning_order {
        puts "  $key: $warn_counts($key)"
    }
}

proc _aprr_preview_list {items {max_items 5}} {
    set item_count [llength $items]
    if {$item_count <= $max_items} {
        return $items
    }

    set last_idx [expr {$max_items - 1}]
    return "[lrange $items 0 $last_idx] ... ($item_count total)"
}

proc _aprr_db_get {db_expr} {
    if {[catch {set value [dbGet $db_expr]}]} {
        return ""
    }
    return $value
}

proc _aprr_truthy {value} {
    foreach item $value {
        set low_item [string tolower $item]
        if {$item eq "1" || $low_item eq "true"} {
            return 1
        }
    }
    return 0
}

proc _aprr_input_skip_reason {port_name} {
    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        return "missing_term"
    }

    set pg_type [_aprr_db_get "$term_ptr.pgType"]
    if {$pg_type ne "" && $pg_type ne "0x0" && $pg_type ne "invalid"} {
        return "pg_type:$pg_type"
    }

    set term_type [_aprr_db_get "$term_ptr.type"]
    if {[lsearch -exact {powerTerm groundTerm clockTerm gatedClockTerm analogTerm} $term_type] >= 0} {
        return "term_type:$term_type"
    }

    foreach attr {isClk isScanClk isSpecial isTieHi isTieLo} {
        if {[_aprr_truthy [_aprr_db_get "$term_ptr.$attr"]]} {
            return "term_$attr"
        }
    }

    foreach attr {isPwrOrGnd isPwr isGnd isClock isCTSClock isAnalog} {
        if {[_aprr_truthy [_aprr_db_get "$term_ptr.net.$attr"]]} {
            return "net_$attr"
        }
    }

    return ""
}

proc _aprr_port_ll {port_name} {
    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        _aprr_warn missing_term "Cannot find top term for port '$port_name'."
        return ""
    }

    set shape_llx [_aprr_db_get "$term_ptr.pinShapes.box_llx"]
    set shape_lly [_aprr_db_get "$term_ptr.pinShapes.box_lly"]

    if {$shape_llx ne "" && $shape_llx ne "0x0" && $shape_lly ne "" && $shape_lly ne "0x0"} {
        set llx [lindex [lsort -real $shape_llx] 0]
        set lly [lindex [lsort -real $shape_lly] 0]
        return [list $llx $lly]
    }

    set pt_x [_aprr_db_get "$term_ptr.pt_x"]
    set pt_y [_aprr_db_get "$term_ptr.pt_y"]
    if {$pt_x eq "" || $pt_x eq "0x0" || $pt_y eq "" || $pt_y eq "0x0"} {
        _aprr_warn missing_port_location "Cannot get location for port '$port_name'."
        return ""
    }

    _aprr_warn missing_pin_shape "No pin shape found for port '$port_name'; using term pt_x/pt_y."
    return [list $pt_x $pt_y]
}

proc _aprr_port_side {port_name} {
    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        return ""
    }

    set side [_aprr_db_get "$term_ptr.side"]
    if {$side eq "" || $side eq "0x0"} {
        return ""
    }
    return $side
}

proc _aprr_filter_sequential_cells {cells} {
    set reg_names [list]

    if {[catch {set cell_count [sizeof_collection $cells]}]} {
        set cell_count [llength $cells]
    }
    if {$cell_count == 0} {
        return $reg_names
    }

    foreach_in_collection cell $cells {
        set inst_name [get_object_name $cell]
        if {$inst_name eq ""} {
            continue
        }

        set inst_ptr [dbGet -e top.insts.name $inst_name -p]
        if {$inst_ptr eq "" || $inst_ptr eq "0x0"} {
            continue
        }

        if {[_aprr_truthy [_aprr_db_get "$inst_ptr.cell.isSequential"]]} {
            lappend reg_names $inst_name
        }
    }

    return [lsort -unique $reg_names]
}

proc _aprr_regs_for_output_port {port_obj {trace_through ""}} {
    if {$trace_through eq ""} {
        set fanin_cmd [list all_fanin -to $port_obj -startpoints_only -only_cells]
    } else {
        set fanin_cmd [list all_fanin -to $port_obj -startpoints_only -only_cells -trace_through $trace_through]
    }

    if {[catch {set cells [eval $fanin_cmd]} err_msg]} {
        _aprr_warn all_fanin_failed "all_fanin failed for output port [get_object_name $port_obj]: $err_msg"
        return [list]
    }

    return [_aprr_filter_sequential_cells $cells]
}

proc _aprr_regs_for_input_port {port_obj {trace_through ""}} {
    if {$trace_through eq ""} {
        set fanout_cmd [list all_fanout -from $port_obj -endpoints_only -only_cells]
    } else {
        set fanout_cmd [list all_fanout -from $port_obj -endpoints_only -only_cells -trace_through $trace_through]
    }

    if {[catch {set cells [eval $fanout_cmd]} err_msg]} {
        _aprr_warn all_fanout_failed "all_fanout failed for input port [get_object_name $port_obj]: $err_msg"
        return [list]
    }

    return [_aprr_filter_sequential_cells $cells]
}

proc _aprr_append_port_record {records_var port_obj port_role square_size exclude_ports trace_through} {
    upvar $records_var records

    set port_name [get_object_name $port_obj]

    if {[lsearch -exact $exclude_ports $port_name] >= 0} {
        _aprr_warn skipped_port "Port '$port_name' skipped by exclude list."
        return "skipped"
    }

    if {$port_role eq "input"} {
        set skip_reason [_aprr_input_skip_reason $port_name]
        if {$skip_reason ne ""} {
            _aprr_warn skipped_input_port "Input port '$port_name' skipped as non-signal port ($skip_reason)."
            return "skipped"
        }
        set regs [_aprr_regs_for_input_port $port_obj $trace_through]
    } else {
        set regs [_aprr_regs_for_output_port $port_obj $trace_through]
    }

    if {[llength $regs] == 0} {
        _aprr_warn no_related_reg "No related register found for $port_role port '$port_name'; skipped."
        return "no_regs"
    }

    set port_ll [_aprr_port_ll $port_name]
    if {$port_ll eq ""} {
        return "no_location"
    }

    set half_size [expr {$square_size / 2.0}]
    lassign $port_ll x y
    set square_box [list \
        [expr {$x - $half_size}] \
        [expr {$y - $half_size}] \
        [expr {$x + $half_size}] \
        [expr {$y + $half_size}]]

    lappend records [list $port_name $x $y $square_box $regs $port_role]
    return "recorded"
}

proc _aprr_merge_records_by_square {records} {
    set groups [list]

    for {set rec_idx 0} {$rec_idx < [llength $records]} {incr rec_idx} {
        set rec_box [lindex [lindex $records $rec_idx] 3]
        set hit_group_idxs [list]

        for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
            set group [lindex $groups $group_idx]
            foreach old_rec_idx $group {
                set old_box [lindex [lindex $records $old_rec_idx] 3]
                if {[_aprr_box_overlap $rec_box $old_box]} {
                    lappend hit_group_idxs $group_idx
                    break
                }
            }
        }

        if {[llength $hit_group_idxs] == 0} {
            lappend groups [list $rec_idx]
            continue
        }

        set new_group [list $rec_idx]
        set new_groups [list]
        for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
            set group [lindex $groups $group_idx]
            if {[lsearch -exact $hit_group_idxs $group_idx] >= 0} {
                set new_group [concat $new_group $group]
            } else {
                lappend new_groups $group
            }
        }

        lappend new_groups [lsort -integer -unique $new_group]
        set groups $new_groups
    }

    return $groups
}

proc _aprr_delete_existing_group {group_name} {
    set group_ptr [dbGet -e top.fplan.groups.name $group_name -p]
    if {$group_ptr eq "" || $group_ptr eq "0x0"} {
        return 0
    }

    catch {unplaceGuide $group_name}

    if {[catch {deleteInstGroup $group_name} err_msg]} {
        _aprr_warn delete_existing_group_failed "Failed to delete existing group '$group_name': $err_msg"
        return 0
    }

    return 1
}

proc _aprr_remove_regs_from_other_groups {reg_names target_group_name remove_from_other_groups} {
    if {!$remove_from_other_groups} {
        return 0
    }

    set remove_count 0

    foreach reg_name $reg_names {
        set reg_ptr [dbGet -e top.insts.name $reg_name -p]
        if {$reg_ptr eq "" || $reg_ptr eq "0x0"} {
            _aprr_warn missing_reg_for_group_cleanup "Cannot find register '$reg_name' while cleaning old group membership."
            continue
        }

        set old_group_names [_aprr_db_get "$reg_ptr.group.name"]
        if {$old_group_names eq "" || $old_group_names eq "0x0"} {
            continue
        }

        foreach old_group_name $old_group_names {
            if {$old_group_name eq "" || $old_group_name eq "0x0"} {
                continue
            }
            if {$old_group_name eq $target_group_name} {
                continue
            }

            if {[catch {deleteInstFromInstGroup $old_group_name $reg_name} err_msg]} {
                _aprr_warn remove_from_old_group_failed "Failed to remove register '$reg_name' from group '$old_group_name': $err_msg"
            } else {
                incr remove_count
            }
        }
    }

    return $remove_count
}

proc create_all_port_reg_regions {{square_size 200} {edge_margin 20} {exclude_ports ""} {trace_through ""}} {
    _aprr_reset_warning_stats

    if {$square_size <= 0} {
        error "square_size must be positive."
    }
    if {$edge_margin < 0} {
        error "edge_margin must be non-negative."
    }

    set records [list]
    set group_prefix "all_port_reg_region"
    set remove_from_other_groups 1
    set output_ports [all_outputs]
    set input_ports [all_inputs]

    if {[catch {set output_count [sizeof_collection $output_ports]}]} {
        set output_count [llength $output_ports]
    }
    if {[catch {set input_count [sizeof_collection $input_ports]}]} {
        set input_count [llength $input_ports]
    }

    if {$output_count == 0 && $input_count == 0} {
        _aprr_warn no_ports "No input or output ports found."
        _aprr_print_warning_summary
        return [list]
    }

    puts "create_all_port_reg_regions: scanning $output_count output port(s) and $input_count input port(s), square_size=$square_size, edge_margin=$edge_margin"

    set output_records 0
    set input_records 0
    set skipped_output_ports 0
    set skipped_input_ports 0

    foreach_in_collection port_obj $output_ports {
        set result [_aprr_append_port_record records $port_obj output $square_size $exclude_ports $trace_through]
        if {$result eq "recorded"} {
            incr output_records
        } elseif {$result eq "skipped"} {
            incr skipped_output_ports
        }
    }

    foreach_in_collection port_obj $input_ports {
        set result [_aprr_append_port_record records $port_obj input $square_size $exclude_ports $trace_through]
        if {$result eq "recorded"} {
            incr input_records
        } elseif {$result eq "skipped"} {
            incr skipped_input_ports
        }
    }

    if {[llength $records] == 0} {
        _aprr_warn no_port_reg_pairs "No signal port/register pairs found."
        _aprr_print_warning_summary
        return [list]
    }

    set groups [_aprr_merge_records_by_square $records]
    set reg_group_map [list]

    for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
        foreach rec_idx [lindex $groups $group_idx] {
            set regs [lindex [lindex $records $rec_idx] 4]
            foreach reg_name $regs {
                set map_idx -1
                for {set search_idx 0} {$search_idx < [llength $reg_group_map]} {incr search_idx 2} {
                    if {[lindex $reg_group_map $search_idx] eq $reg_name} {
                        set map_idx $search_idx
                        break
                    }
                }
                if {$map_idx < 0} {
                    lappend reg_group_map $reg_name [list $group_idx]
                } else {
                    set value_idx [expr {$map_idx + 1}]
                    set old_groups [lindex $reg_group_map $value_idx]
                    if {[lsearch -exact $old_groups $group_idx] < 0} {
                        lset reg_group_map $value_idx [lsort -integer -unique [concat $old_groups [list $group_idx]]]
                    }
                }
            }
        }
    }

    set ambiguous_regs [list]
    for {set idx 0} {$idx < [llength $reg_group_map]} {incr idx 2} {
        set reg_name [lindex $reg_group_map $idx]
        set group_list [lindex $reg_group_map [expr {$idx + 1}]]
        if {[llength $group_list] > 1} {
            _aprr_warn ambiguous_reg "Register '$reg_name' belongs to multiple port regions ($group_list); it will not be constrained."
            lappend ambiguous_regs $reg_name
        }
    }

    set core_box [_aprr_db_get top.fplan.coreBox]
    if {$core_box eq "" || $core_box eq "0x0"} {
        error "Cannot get top.fplan.coreBox."
    }

    set created_region_names [list]
    set old_group_memberships_removed 0

    for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
        set group [lindex $groups $group_idx]
        set port_names [list]
        set raw_port_names [list]
        set port_xs [list]
        set port_ys [list]
        set square_boxes [list]
        set group_regs [list]

        foreach rec_idx $group {
            set rec [lindex $records $rec_idx]
            set port_name [lindex $rec 0]
            set port_role [lindex $rec 5]

            lappend port_names "${port_role}:$port_name"
            lappend raw_port_names $port_name
            lappend port_xs [lindex $rec 1]
            lappend port_ys [lindex $rec 2]
            lappend square_boxes [lindex $rec 3]

            foreach reg_name [lindex $rec 4] {
                if {[lsearch -exact $ambiguous_regs $reg_name] < 0} {
                    lappend group_regs $reg_name
                }
            }
        }

        set group_regs [lsort -unique $group_regs]
        if {[llength $group_regs] == 0} {
            _aprr_warn empty_region_candidate "Region candidate with [llength $port_names] port record(s) has no non-ambiguous registers; skipped. Port sample: [_aprr_preview_list $port_names]"
            continue
        }

        set same_x [_aprr_same_coord $port_xs]
        set same_y [_aprr_same_coord $port_ys]
        if {!$same_x && !$same_y} {
            _aprr_warn unaligned_ports "Ports in one merged region are not aligned by X or Y. Port sample: [_aprr_preview_list $port_names 10]"
            _aprr_print_warning_summary
            error "Aborting create_all_port_reg_regions."
        }

        set region_box [_aprr_box_union $square_boxes]
        lassign $region_box llx lly urx ury

        set min_port_x [lindex [lsort -real $port_xs] 0]
        set max_port_x [lindex [lsort -real $port_xs] end]
        set min_port_y [lindex [lsort -real $port_ys] 0]
        set max_port_y [lindex [lsort -real $port_ys] end]

        set shrink_dir ""
        if {$same_y && !$same_x} {
            set shrink_dir "x"
        } elseif {$same_x && !$same_y} {
            set shrink_dir "y"
        } elseif {$same_x && $same_y} {
            set first_port_name [lindex $raw_port_names 0]
            set port_side [_aprr_port_side $first_port_name]
            if {$port_side eq "North" || $port_side eq "South"} {
                set shrink_dir "x"
            } elseif {$port_side eq "East" || $port_side eq "West"} {
                set shrink_dir "y"
            } else {
                _aprr_warn unknown_port_direction "Cannot determine port direction for [llength $port_names] port record(s); keep merged box before core clipping. Port sample: [_aprr_preview_list $port_names]"
            }
        }

        if {$shrink_dir eq "x"} {
            set llx [_aprr_max2 $llx [expr {$min_port_x - $edge_margin}]]
            set urx [_aprr_min2 $urx [expr {$max_port_x + $edge_margin}]]
        }

        if {$shrink_dir eq "y"} {
            set lly [_aprr_max2 $lly [expr {$min_port_y - $edge_margin}]]
            set ury [_aprr_min2 $ury [expr {$max_port_y + $edge_margin}]]
        }

        if {$urx <= $llx || $ury <= $lly} {
            _aprr_warn zero_area_after_tighten "Tightened region has zero area; skipped. Port sample: [_aprr_preview_list $port_names]"
            continue
        }

        set tightened_box [list $llx $lly $urx $ury]
        set clipped_boxes [dbShape $tightened_box AND $core_box]
        if {[llength $clipped_boxes] == 0} {
            _aprr_warn no_core_overlap "Region does not overlap core box; skipped. Port sample: [_aprr_preview_list $port_names]"
            continue
        }
        if {[llength $clipped_boxes] > 1} {
            _aprr_warn multi_rect_core_clip "Core clipping produced multiple rectangles; using the first rectangle. Port sample: [_aprr_preview_list $port_names]"
        }

        set final_box [lindex $clipped_boxes 0]
        lassign $final_box fllx flly furx fury
        if {$furx <= $fllx || $fury <= $flly} {
            _aprr_warn zero_area_after_core_clip "Core-clipped region has zero area; skipped. Port sample: [_aprr_preview_list $port_names]"
            continue
        }

        set group_name "${group_prefix}_${group_idx}"
        _aprr_delete_existing_group $group_name
        incr old_group_memberships_removed [_aprr_remove_regs_from_other_groups $group_regs $group_name $remove_from_other_groups]

        createInstGroup $group_name
        addInstToInstGroup $group_name $group_regs
        createRegion $group_name $fllx $flly $furx $fury

        lappend created_region_names $group_name
    }

    puts "Summary:"
    puts "  output ports scanned       : $output_count"
    puts "  input ports scanned        : $input_count"
    puts "  output ports skipped       : $skipped_output_ports"
    puts "  input ports skipped        : $skipped_input_ports"
    puts "  output ports with reg data : $output_records"
    puts "  input ports with reg data  : $input_records"
    puts "  merged region candidates   : [llength $groups]"
    puts "  ambiguous regs skipped     : [llength $ambiguous_regs]"
    puts "  old group memberships rm   : $old_group_memberships_removed"
    puts "  regions created            : [llength $created_region_names]"
    _aprr_print_warning_summary

    return [list \
        output_ports $output_count \
        input_ports $input_count \
        skipped_output_ports $skipped_output_ports \
        skipped_input_ports $skipped_input_ports \
        output_records $output_records \
        input_records $input_records \
        region_candidates [llength $groups] \
        ambiguous_regs [llength $ambiguous_regs] \
        old_group_memberships_removed $old_group_memberships_removed \
        created_regions [llength $created_region_names]]
}
