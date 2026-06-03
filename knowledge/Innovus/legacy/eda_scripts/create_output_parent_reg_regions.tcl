# Create placement regions for registers that launch timing paths to output ports.
#
# Usage:
#   source create_output_parent_reg_regions.tcl
#   create_output_parent_reg_regions
#
# Optional distance controls:
#   create_output_parent_reg_regions 200 20
#     200: side length of each output-port square, centered at port llx/lly
#      20: margin used to tighten the region edge along the port line
#
# Optional log control:
#   set _oprr_warning_limit 0
#     Print only warning categories/counts in the final summary.

proc get_output_parent_regs {{output_ports ""} {trace_through ""}} {
    set reg_names [list]

    if {$output_ports eq ""} {
        set output_ports [all_outputs]
    }

    if {[catch {set output_count [sizeof_collection $output_ports]}]} {
        set output_count [llength $output_ports]
    }

    if {$output_count == 0} {
        puts "Warning: No output ports found."
        return $reg_names
    }

    if {$trace_through eq ""} {
        set fanin_cmd [list all_fanin -to $output_ports -startpoints_only -only_cells]
    } else {
        set fanin_cmd [list all_fanin -to $output_ports -startpoints_only -only_cells -trace_through $trace_through]
    }

    if {[catch {set start_cells [eval $fanin_cmd]} err_msg]} {
        puts "Error: all_fanin failed: $err_msg"
        return $reg_names
    }

    if {[catch {set start_count [sizeof_collection $start_cells]}]} {
        set start_count [llength $start_cells]
    }

    if {$start_count == 0} {
        return $reg_names
    }

    foreach_in_collection cell $start_cells {
        set inst_name [get_object_name $cell]
        if {$inst_name eq ""} {
            continue
        }

        set inst_ptr [dbGet -e top.insts.name $inst_name -p]
        if {$inst_ptr eq "" || $inst_ptr eq "0x0"} {
            continue
        }

        if {[dbGet $inst_ptr.cell.isSequential] == 1} {
            lappend reg_names $inst_name
        }
    }

    return [lsort -unique $reg_names]
}

proc _oprr_min2 {a b} {
    if {$a < $b} {
        return $a
    }
    return $b
}

proc _oprr_max2 {a b} {
    if {$a > $b} {
        return $a
    }
    return $b
}

proc _oprr_box_overlap {box_a box_b} {
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

proc _oprr_box_union {boxes} {
    set first_box [lindex $boxes 0]
    lassign $first_box llx lly urx ury

    foreach box [lrange $boxes 1 end] {
        lassign $box x1 y1 x2 y2
        set llx [_oprr_min2 $llx $x1]
        set lly [_oprr_min2 $lly $y1]
        set urx [_oprr_max2 $urx $x2]
        set ury [_oprr_max2 $ury $y2]
    }

    return [list $llx $lly $urx $ury]
}

proc _oprr_same_coord {values} {
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

proc _oprr_reset_warning_stats {} {
    global _oprr_warn_counts
    global _oprr_warn_printed
    global _oprr_warning_order
    global _oprr_warning_limit

    catch {unset _oprr_warn_counts}
    catch {unset _oprr_warn_printed}
    set _oprr_warning_order [list]

    if {![info exists _oprr_warning_limit]} {
        set _oprr_warning_limit 3
    }
}

proc _oprr_warn {key message} {
    global _oprr_warn_counts
    global _oprr_warn_printed
    global _oprr_warning_order
    global _oprr_warning_limit

    if {![info exists _oprr_warning_limit]} {
        set _oprr_warning_limit 3
    }

    if {![info exists _oprr_warn_counts($key)]} {
        set _oprr_warn_counts($key) 0
        set _oprr_warn_printed($key) 0
        lappend _oprr_warning_order $key
    }

    incr _oprr_warn_counts($key)

    if {$_oprr_warn_printed($key) < $_oprr_warning_limit} {
        puts "Warning: $message"
        incr _oprr_warn_printed($key)
    } elseif {$_oprr_warn_printed($key) == $_oprr_warning_limit} {
        puts "Warning: Further '$key' warnings suppressed."
        incr _oprr_warn_printed($key)
    }
}

proc _oprr_print_warning_summary {} {
    global _oprr_warn_counts
    global _oprr_warning_order

    if {![info exists _oprr_warning_order] || [llength $_oprr_warning_order] == 0} {
        puts "Warnings: 0"
        return
    }

    puts "Warning summary:"
    foreach key $_oprr_warning_order {
        puts "  $key: $_oprr_warn_counts($key)"
    }
}

proc _oprr_preview_list {items {max_items 5}} {
    set item_count [llength $items]
    if {$item_count <= $max_items} {
        return $items
    }

    set last_idx [expr {$max_items - 1}]
    return "[lrange $items 0 $last_idx] ... ($item_count total)"
}

proc _oprr_port_ll {port_name} {
    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        _oprr_warn missing_term "Cannot find top term for output port '$port_name'."
        return ""
    }

    set shape_llx [dbGet $term_ptr.pinShapes.box_llx]
    set shape_lly [dbGet $term_ptr.pinShapes.box_lly]

    if {$shape_llx ne "" && $shape_llx ne "0x0" && $shape_lly ne "" && $shape_lly ne "0x0"} {
        set llx [lindex [lsort -real $shape_llx] 0]
        set lly [lindex [lsort -real $shape_lly] 0]
        return [list $llx $lly]
    }

    set pt_x [dbGet $term_ptr.pt_x]
    set pt_y [dbGet $term_ptr.pt_y]
    if {$pt_x eq "" || $pt_x eq "0x0" || $pt_y eq "" || $pt_y eq "0x0"} {
        _oprr_warn missing_port_location "Cannot get location for output port '$port_name'."
        return ""
    }

    _oprr_warn missing_pin_shape "No pin shape found for output port '$port_name'; using term pt_x/pt_y."
    return [list $pt_x $pt_y]
}

proc _oprr_port_side {port_name} {
    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        return ""
    }

    set side [dbGet $term_ptr.side]
    if {$side eq "" || $side eq "0x0"} {
        return ""
    }
    return $side
}

proc _oprr_regs_for_output_port {port_obj {trace_through ""}} {
    set reg_names [list]

    if {$trace_through eq ""} {
        set fanin_cmd [list all_fanin -to $port_obj -startpoints_only -only_cells]
    } else {
        set fanin_cmd [list all_fanin -to $port_obj -startpoints_only -only_cells -trace_through $trace_through]
    }

    if {[catch {set start_cells [eval $fanin_cmd]} err_msg]} {
        _oprr_warn all_fanin_failed "all_fanin failed for port [get_object_name $port_obj]: $err_msg"
        return $reg_names
    }

    if {[catch {set start_count [sizeof_collection $start_cells]}]} {
        set start_count [llength $start_cells]
    }
    if {$start_count == 0} {
        return $reg_names
    }

    foreach_in_collection cell $start_cells {
        set inst_name [get_object_name $cell]
        if {$inst_name eq ""} {
            continue
        }

        set inst_ptr [dbGet -e top.insts.name $inst_name -p]
        if {$inst_ptr eq "" || $inst_ptr eq "0x0"} {
            continue
        }

        if {[dbGet $inst_ptr.cell.isSequential] == 1} {
            lappend reg_names $inst_name
        }
    }

    return [lsort -unique $reg_names]
}

proc _oprr_merge_records_by_square {records} {
    set groups [list]

    for {set rec_idx 0} {$rec_idx < [llength $records]} {incr rec_idx} {
        set rec_box [lindex [lindex $records $rec_idx] 3]
        set hit_group_idxs [list]

        for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
            set group [lindex $groups $group_idx]
            foreach old_rec_idx $group {
                set old_box [lindex [lindex $records $old_rec_idx] 3]
                if {[_oprr_box_overlap $rec_box $old_box]} {
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

proc _oprr_delete_existing_group {group_name} {
    set group_ptr [dbGet -e top.fplan.groups.name $group_name -p]
    if {$group_ptr eq "" || $group_ptr eq "0x0"} {
        return 0
    }

    catch {unplaceGuide $group_name}

    if {[catch {deleteInstGroup $group_name} err_msg]} {
        _oprr_warn delete_existing_group_failed "Failed to delete existing group '$group_name': $err_msg"
        return 0
    }

    return 1
}

proc _oprr_remove_regs_from_other_groups {reg_names target_group_name} {
    set remove_count 0

    foreach reg_name $reg_names {
        set reg_ptr [dbGet -e top.insts.name $reg_name -p]
        if {$reg_ptr eq "" || $reg_ptr eq "0x0"} {
            _oprr_warn missing_reg_for_group_cleanup "Cannot find register '$reg_name' while cleaning old group membership."
            continue
        }

        set old_group_names [dbGet $reg_ptr.group.name]
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
                _oprr_warn remove_from_old_group_failed "Failed to remove register '$reg_name' from group '$old_group_name': $err_msg"
            } else {
                incr remove_count
            }
        }
    }

    return $remove_count
}

proc create_output_parent_reg_regions {{square_size 200} {edge_margin 20}} {
    _oprr_reset_warning_stats

    if {$square_size <= 0} {
        error "square_size must be positive."
    }
    if {$edge_margin < 0} {
        error "edge_margin must be non-negative."
    }

    set half_size [expr {$square_size / 2.0}]
    set records [list]
    set output_ports [all_outputs]

    if {[catch {set output_count [sizeof_collection $output_ports]}]} {
        set output_count [llength $output_ports]
    }
    if {$output_count == 0} {
        _oprr_warn no_output_ports "No output ports found."
        _oprr_print_warning_summary
        return [list]
    }

    puts "create_output_parent_reg_regions: scanning $output_count output port(s), square_size=$square_size, edge_margin=$edge_margin"

    foreach_in_collection port_obj $output_ports {
        set port_name [get_object_name $port_obj]
        set port_ll [_oprr_port_ll $port_name]
        if {$port_ll eq ""} {
            continue
        }

        set regs [_oprr_regs_for_output_port $port_obj]
        if {[llength $regs] == 0} {
            _oprr_warn no_parent_reg "No parent register found for output port '$port_name'; skipped."
            continue
        }

        lassign $port_ll x y
        set square_box [list \
            [expr {$x - $half_size}] \
            [expr {$y - $half_size}] \
            [expr {$x + $half_size}] \
            [expr {$y + $half_size}]]

        lappend records [list $port_name $x $y $square_box $regs]
    }

    if {[llength $records] == 0} {
        _oprr_warn no_port_reg_pairs "No output port/register pairs found."
        _oprr_print_warning_summary
        return [list]
    }

    set groups [_oprr_merge_records_by_square $records]
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
            _oprr_warn ambiguous_reg "Register '$reg_name' belongs to multiple output regions ($group_list); it will not be constrained."
            lappend ambiguous_regs $reg_name
        }
    }

    set core_box [dbGet top.fplan.coreBox]
    if {$core_box eq "" || $core_box eq "0x0"} {
        error "Cannot get top.fplan.coreBox."
    }

    set created_region_names [list]
    set old_group_memberships_removed 0

    for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
        set group [lindex $groups $group_idx]
        set port_names [list]
        set port_xs [list]
        set port_ys [list]
        set square_boxes [list]
        set group_regs [list]

        foreach rec_idx $group {
            set rec [lindex $records $rec_idx]
            lappend port_names [lindex $rec 0]
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
            _oprr_warn empty_region_candidate "Region candidate with [llength $port_names] port(s) has no non-ambiguous registers; skipped. Port sample: [_oprr_preview_list $port_names]"
            continue
        }

        set same_x [_oprr_same_coord $port_xs]
        set same_y [_oprr_same_coord $port_ys]
        if {!$same_x && !$same_y} {
            _oprr_warn unaligned_ports "Ports in one merged region are not aligned by X or Y. Port sample: [_oprr_preview_list $port_names 10]"
            _oprr_print_warning_summary
            error "Aborting create_output_parent_reg_regions."
        }

        set region_box [_oprr_box_union $square_boxes]
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
            set port_side [_oprr_port_side [lindex $port_names 0]]
            if {$port_side eq "North" || $port_side eq "South"} {
                set shrink_dir "x"
            } elseif {$port_side eq "East" || $port_side eq "West"} {
                set shrink_dir "y"
            } else {
                _oprr_warn unknown_port_direction "Cannot determine port direction for [llength $port_names] port(s); keep merged 200x200 box before core clipping. Port sample: [_oprr_preview_list $port_names]"
            }
        }

        if {$shrink_dir eq "x"} {
            set llx [_oprr_max2 $llx [expr {$min_port_x - $edge_margin}]]
            set urx [_oprr_min2 $urx [expr {$max_port_x + $edge_margin}]]
        }

        if {$shrink_dir eq "y"} {
            set lly [_oprr_max2 $lly [expr {$min_port_y - $edge_margin}]]
            set ury [_oprr_min2 $ury [expr {$max_port_y + $edge_margin}]]
        }

        if {$urx <= $llx || $ury <= $lly} {
            _oprr_warn zero_area_after_tighten "Tightened region has zero area; skipped. Port sample: [_oprr_preview_list $port_names]"
            continue
        }

        set tightened_box [list $llx $lly $urx $ury]
        set clipped_boxes [dbShape $tightened_box AND $core_box]
        if {[llength $clipped_boxes] == 0} {
            _oprr_warn no_core_overlap "Region does not overlap core box; skipped. Port sample: [_oprr_preview_list $port_names]"
            continue
        }
        if {[llength $clipped_boxes] > 1} {
            _oprr_warn multi_rect_core_clip "Core clipping produced multiple rectangles; using the first rectangle. Port sample: [_oprr_preview_list $port_names]"
        }

        set final_box [lindex $clipped_boxes 0]
        lassign $final_box fllx flly furx fury
        if {$furx <= $fllx || $fury <= $flly} {
            _oprr_warn zero_area_after_core_clip "Core-clipped region has zero area; skipped. Port sample: [_oprr_preview_list $port_names]"
            continue
        }

        set group_name "out_parent_reg_region_${group_idx}"
        _oprr_delete_existing_group $group_name
        incr old_group_memberships_removed [_oprr_remove_regs_from_other_groups $group_regs $group_name]

        createInstGroup $group_name
        addInstToInstGroup $group_name $group_regs
        createRegion $group_name $fllx $flly $furx $fury

        lappend created_region_names $group_name
    }

    puts "Summary:"
    puts "  output ports scanned       : $output_count"
    puts "  output ports with reg data : [llength $records]"
    puts "  merged region candidates   : [llength $groups]"
    puts "  ambiguous regs skipped     : [llength $ambiguous_regs]"
    puts "  old group memberships rm   : $old_group_memberships_removed"
    puts "  regions created            : [llength $created_region_names]"
    _oprr_print_warning_summary

    return [list \
        output_ports $output_count \
        port_records [llength $records] \
        region_candidates [llength $groups] \
        ambiguous_regs [llength $ambiguous_regs] \
        old_group_memberships_removed $old_group_memberships_removed \
        created_regions [llength $created_region_names]]
}
