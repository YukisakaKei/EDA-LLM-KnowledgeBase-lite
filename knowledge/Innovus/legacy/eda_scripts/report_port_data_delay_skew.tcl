# Report per-port data path delay and clock skew from Innovus timing paths.
#
# Usage:
#   source workspace/innovus-legacy-scripts/report_port_data_delay_skew.tcl
#   report_port_data_delay_skew
#   report_port_data_delay_skew -view setup_view
#   report_port_data_delay_skew -view setup_view -out_dir reports -prefix my_block
#   report_port_data_delay_skew -view setup_view -input_file in.rpt -output_file out.rpt
#   report_port_data_delay_skew -view setup_view -debug
#
# Notes:
#   - Input ports are timed with report_timing -from <port>.
#   - Output ports are timed with report_timing -to <port>.
#   - path_delay is reported as data path delay.
#   - skew is reported as clock skew.

proc _pdds_usage {} {
    return "Usage: report_port_data_delay_skew ?-view view_name? ?-out_dir dir? ?-prefix prefix? ?-delay_type late|early? ?-input_file file? ?-output_file file? ?-debug?"
}

proc _pdds_db_get {db_expr} {
    if {[catch {set value [dbGet $db_expr]}]} {
        return ""
    }
    return $value
}

proc _pdds_truthy {value} {
    foreach item $value {
        set low_item [string tolower $item]
        if {$item eq "1" || $low_item eq "true"} {
            return 1
        }
    }
    return 0
}

proc _pdds_collection_size {collection} {
    if {[catch {set count [sizeof_collection $collection]}]} {
        return [llength $collection]
    }
    return $count
}

proc _pdds_object_name {object} {
    if {[catch {set name [get_object_name $object]}]} {
        return ""
    }
    return $name
}

proc _pdds_object_names {collection} {
    if {$collection eq ""} {
        return ""
    }
    if {[catch {set names [get_object_name $collection]}]} {
        return ""
    }
    return $names
}

proc _pdds_get_property {object property {default "NA"}} {
    if {[catch {set value [get_property $object $property -quiet]}]} {
        if {[catch {set value [get_property $object $property]}]} {
            return $default
        }
    }

    if {$value eq ""} {
        return $default
    }
    return $value
}

proc _pdds_format_value {value} {
    if {$value eq ""} {
        return "NA"
    }
    if {[string is double -strict $value]} {
        return [format "%.6f" $value]
    }
    return $value
}

proc _pdds_metric_value {record key {default ""}} {
    set idx [lsearch -exact $record $key]
    if {$idx < 0} {
        return $default
    }
    return [lindex $record [expr {$idx + 1}]]
}

proc _pdds_metric_set {record key value} {
    set idx [lsearch -exact $record $key]
    if {$idx < 0} {
        lappend record $key $value
    } else {
        lset record [expr {$idx + 1}] $value
    }
    return $record
}

proc _pdds_metric_incr {record key} {
    set value [_pdds_metric_value $record $key 0]
    set value [expr {$value + 1}]
    return [_pdds_metric_set $record $key $value]
}

proc _pdds_sort_by_port {a b} {
    return [string compare -nocase [_pdds_metric_value $a port_name] [_pdds_metric_value $b port_name]]
}

proc _pdds_sort_by_slack {a b} {
    set a_slack [_pdds_metric_value $a slack]
    set b_slack [_pdds_metric_value $b slack]

    set a_is_num [string is double -strict $a_slack]
    set b_is_num [string is double -strict $b_slack]

    if {$a_is_num && $b_is_num} {
        if {$a_slack < $b_slack} {
            return -1
        }
        if {$a_slack > $b_slack} {
            return 1
        }
        return [_pdds_sort_by_port $a $b]
    }

    if {$a_is_num} {
        return -1
    }
    if {$b_is_num} {
        return 1
    }
    return [_pdds_sort_by_port $a $b]
}

proc _pdds_sort_by_delay {a b} {
    set a_delay [_pdds_metric_value $a data_path_delay]
    set b_delay [_pdds_metric_value $b data_path_delay]

    set a_is_num [string is double -strict $a_delay]
    set b_is_num [string is double -strict $b_delay]

    if {$a_is_num && $b_is_num} {
        if {$a_delay > $b_delay} {
            return -1
        }
        if {$a_delay < $b_delay} {
            return 1
        }
        return [_pdds_sort_by_port $a $b]
    }

    if {$a_is_num} {
        return -1
    }
    if {$b_is_num} {
        return 1
    }
    return [_pdds_sort_by_port $a $b]
}

proc _pdds_sort_by_skew {a b} {
    set a_skew [_pdds_metric_value $a clock_skew]
    set b_skew [_pdds_metric_value $b clock_skew]

    set a_is_num [string is double -strict $a_skew]
    set b_is_num [string is double -strict $b_skew]

    if {$a_is_num && $b_is_num} {
        if {$a_skew > $b_skew} {
            return -1
        }
        if {$a_skew < $b_skew} {
            return 1
        }
        return [_pdds_sort_by_port $a $b]
    }

    if {$a_is_num} {
        return -1
    }
    if {$b_is_num} {
        return 1
    }
    return [_pdds_sort_by_port $a $b]
}

proc _pdds_sanitize_filename_part {value} {
    set clean $value
    regsub -all {[^A-Za-z0-9_.-]} $clean {_} clean
    return $clean
}

proc _pdds_join_path {dir file_name} {
    if {$dir eq "" || $dir eq "."} {
        return $file_name
    }
    return [file join $dir $file_name]
}

proc _pdds_ensure_parent_dir {file_name} {
    set dir_name [file dirname $file_name]
    if {$dir_name ne "" && $dir_name ne "."} {
        file mkdir $dir_name
    }
}

proc _pdds_build_clock_source_cache {} {
    global _pdds_clock_source_port
    global _pdds_clock_source_cache_ready

    catch {unset _pdds_clock_source_port}
    array set _pdds_clock_source_port {}

    if {[catch {set clocks [all_clocks]}]} {
        set _pdds_clock_source_cache_ready -1
        return 0
    }

    foreach_in_collection clk $clocks {
        if {[catch {set sources [get_property $clk sources -quiet]}]} {
            if {[catch {set sources [get_property $clk sources]}]} {
                continue
            }
        }

        foreach_in_collection src $sources {
            set src_name [_pdds_object_name $src]
            if {$src_name ne ""} {
                set _pdds_clock_source_port($src_name) 1
            }
        }
    }

    set _pdds_clock_source_cache_ready 1
    return [array size _pdds_clock_source_port]
}

proc _pdds_is_clock_port {port_name} {
    global _pdds_clock_source_port
    global _pdds_clock_source_cache_ready

    if {![info exists _pdds_clock_source_cache_ready]} {
        _pdds_build_clock_source_cache
    }

    if {[info exists _pdds_clock_source_port($port_name)]} {
        return 1
    }

    set term_ptr [dbGet -e top.terms.name $port_name -p]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        return 0
    }

    set term_type [_pdds_db_get "$term_ptr.type"]
    if {[lsearch -exact {clockTerm gatedClockTerm} $term_type] >= 0} {
        return 1
    }

    foreach attr {isClk isScanClk} {
        if {[_pdds_truthy [_pdds_db_get "$term_ptr.$attr"]]} {
            return 1
        }
    }

    foreach attr {isClock isCTSClock} {
        if {[_pdds_truthy [_pdds_db_get "$term_ptr.net.$attr"]]} {
            return 1
        }
    }

    return 0
}

proc _pdds_first_timing_path {port_obj direction view_name delay_type} {
    set cmd [list report_timing -collection -path_type full_clock -max_paths 1 -nworst 1]

    if {$delay_type eq "early"} {
        lappend cmd -early
    } else {
        lappend cmd -late
    }

    if {$view_name ne ""} {
        lappend cmd -view $view_name
    }

    if {$direction eq "input"} {
        lappend cmd -from $port_obj
    } else {
        lappend cmd -to $port_obj
    }

    if {[catch {set paths [eval $cmd]} err_msg]} {
        return [list status ERROR message $err_msg path ""]
    }

    if {[_pdds_collection_size $paths] == 0} {
        return [list status NO_PATH message "No timing path found" path ""]
    }

    set first_path ""
    foreach_in_collection path $paths {
        set first_path $path
        break
    }

    if {$first_path eq ""} {
        return [list status NO_PATH message "No timing path found" path ""]
    }

    return [list status OK message "" path $first_path]
}

proc _pdds_record_for_port {port_obj direction view_name delay_type} {
    set port_name [_pdds_object_name $port_obj]

    if {$port_name eq ""} {
        return [list status ERROR port_name "" message "Cannot get port name"]
    }

    if {[_pdds_is_clock_port $port_name]} {
        return [list status CLOCK_SKIP port_name $port_name message "Clock port skipped"]
    }

    set path_result [_pdds_first_timing_path $port_obj $direction $view_name $delay_type]
    set status [_pdds_metric_value $path_result status]

    if {$status ne "OK"} {
        return [list \
            status $status \
            port_name $port_name \
            slack NA \
            data_path_delay NA \
            clock_skew NA \
            path_group NA \
            view_name $view_name \
            startpoint NA \
            endpoint NA \
            launch_clock NA \
            capture_clock NA \
            message [_pdds_metric_value $path_result message]]
    }

    set path [_pdds_metric_value $path_result path]
    set launch_point [_pdds_get_property $path launching_point ""]
    set capture_point [_pdds_get_property $path capturing_point ""]
    set launch_clock [_pdds_get_property $path launching_clock ""]
    set capture_clock [_pdds_get_property $path capturing_clock ""]

    return [list \
        status OK \
        port_name $port_name \
        slack [_pdds_get_property $path slack] \
        data_path_delay [_pdds_get_property $path path_delay] \
        clock_skew [_pdds_get_property $path skew] \
        path_group [_pdds_get_property $path path_group_name] \
        view_name [_pdds_get_property $path view_name $view_name] \
        startpoint [_pdds_object_names $launch_point] \
        endpoint [_pdds_object_names $capture_point] \
        launch_clock [_pdds_object_names $launch_clock] \
        capture_clock [_pdds_object_names $capture_clock] \
        message ""]
}

proc _pdds_scan_ports {ports direction view_name delay_type {port_limit 0}} {
    set records [list]
    set stats [list total 0 clock_skip 0 reported 0 no_path 0 error 0 debug_limit $port_limit debug_truncated 0]
    set non_clock_count 0

    foreach_in_collection port_obj $ports {
        set record [_pdds_record_for_port $port_obj $direction $view_name $delay_type]
        set status [_pdds_metric_value $record status]

        set stats [_pdds_metric_incr $stats total]
        if {$status eq "OK"} {
            set stats [_pdds_metric_incr $stats reported]
            lappend records $record
        } elseif {$status eq "CLOCK_SKIP"} {
            set stats [_pdds_metric_incr $stats clock_skip]
        } elseif {$status eq "NO_PATH"} {
            set stats [_pdds_metric_incr $stats no_path]
            lappend records $record
        } else {
            set stats [_pdds_metric_incr $stats error]
            lappend records $record
        }

        if {$status ne "CLOCK_SKIP"} {
            incr non_clock_count
        }

        if {$port_limit > 0 && $non_clock_count >= $port_limit} {
            set stats [_pdds_metric_set $stats debug_truncated 1]
            break
        }
    }

    return [list stats $stats records $records]
}

proc _pdds_numeric_summary {records key} {
    set count 0
    set sum 0.0
    set min_value ""
    set max_value ""

    foreach record $records {
        set value [_pdds_metric_value $record $key]
        if {![string is double -strict $value]} {
            continue
        }

        if {$count == 0 || $value < $min_value} {
            set min_value $value
        }
        if {$count == 0 || $value > $max_value} {
            set max_value $value
        }

        set sum [expr {$sum + $value}]
        incr count
    }

    if {$count == 0} {
        return [list count 0 min NA max NA avg NA]
    }

    return [list \
        count $count \
        min [_pdds_format_value $min_value] \
        max [_pdds_format_value $max_value] \
        avg [_pdds_format_value [expr {$sum / double($count)}]]]
}

proc _pdds_write_report {file_name direction view_name delay_type stats records} {
    set sorted_records [lsort -command _pdds_sort_by_port $records]
    set sorted_by_slack [lsort -command _pdds_sort_by_slack $records]
    set slack_summary [_pdds_numeric_summary $records slack]
    set delay_summary [_pdds_numeric_summary $records data_path_delay]
    set skew_summary [_pdds_numeric_summary $records clock_skew]

    _pdds_ensure_parent_dir $file_name
    set fp [open $file_name w]

    puts $fp "Port Data Path Delay and Clock Skew Report"
    puts $fp "Direction       : $direction"
    puts $fp "Analysis view   : [expr {$view_name eq "" ? "active/default" : $view_name}]"
    puts $fp "Delay type      : $delay_type"
    puts $fp "Generated at    : [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    puts $fp ""

    puts $fp "Summary"
    puts $fp "  ports scanned      : [_pdds_metric_value $stats total]"
    puts $fp "  clock ports skipped: [_pdds_metric_value $stats clock_skip]"
    puts $fp "  reported ports     : [_pdds_metric_value $stats reported]"
    puts $fp "  ports without path : [_pdds_metric_value $stats no_path]"
    puts $fp "  ports with errors  : [_pdds_metric_value $stats error]"
    if {[_pdds_metric_value $stats debug_limit 0] > 0} {
        puts $fp "  debug port limit   : [_pdds_metric_value $stats debug_limit]"
        puts $fp "  debug truncated    : [_pdds_metric_value $stats debug_truncated]"
    }
    puts $fp "  slack count/min/avg/max           : [_pdds_metric_value $slack_summary count] / [_pdds_metric_value $slack_summary min] / [_pdds_metric_value $slack_summary avg] / [_pdds_metric_value $slack_summary max]"
    puts $fp "  data path delay count/min/avg/max : [_pdds_metric_value $delay_summary count] / [_pdds_metric_value $delay_summary min] / [_pdds_metric_value $delay_summary avg] / [_pdds_metric_value $delay_summary max]"
    puts $fp "  clock skew count/min/avg/max      : [_pdds_metric_value $skew_summary count] / [_pdds_metric_value $skew_summary min] / [_pdds_metric_value $skew_summary avg] / [_pdds_metric_value $skew_summary max]"
    puts $fp ""

    puts $fp "Worst 10 Ports By Slack"
    puts $fp [format "%-6s %-40s %14s %18s %14s %-20s %-20s" "Rank" "Port" "Slack" "DataPathDelay" "ClockSkew" "PathGroup" "View"]
    puts $fp [string repeat "-" 140]
    set rank 1
    foreach record $sorted_by_slack {
        if {$rank > 10} {
            break
        }
        if {![string is double -strict [_pdds_metric_value $record slack]]} {
            continue
        }
        puts $fp [format "%-6d %-40s %14s %18s %14s %-20s %-20s" \
            $rank \
            [_pdds_metric_value $record port_name] \
            [_pdds_format_value [_pdds_metric_value $record slack]] \
            [_pdds_format_value [_pdds_metric_value $record data_path_delay]] \
            [_pdds_format_value [_pdds_metric_value $record clock_skew]] \
            [_pdds_metric_value $record path_group] \
            [_pdds_metric_value $record view_name]]
        incr rank
    }
    if {$rank == 1} {
        puts $fp "  NA"
    }
    puts $fp ""

    set sorted_by_delay [lsort -command _pdds_sort_by_delay $records]
    puts $fp "Top 10 Ports By Data Path Delay"
    puts $fp [format "%-6s %-40s %14s %18s %14s %-20s %-20s" "Rank" "Port" "Slack" "DataPathDelay" "ClockSkew" "PathGroup" "View"]
    puts $fp [string repeat "-" 140]
    set rank 1
    foreach record $sorted_by_delay {
        if {$rank > 10} {
            break
        }
        if {![string is double -strict [_pdds_metric_value $record data_path_delay]]} {
            continue
        }
        puts $fp [format "%-6d %-40s %14s %18s %14s %-20s %-20s" \
            $rank \
            [_pdds_metric_value $record port_name] \
            [_pdds_format_value [_pdds_metric_value $record slack]] \
            [_pdds_format_value [_pdds_metric_value $record data_path_delay]] \
            [_pdds_format_value [_pdds_metric_value $record clock_skew]] \
            [_pdds_metric_value $record path_group] \
            [_pdds_metric_value $record view_name]]
        incr rank
    }
    if {$rank == 1} {
        puts $fp "  NA"
    }
    puts $fp ""

    set sorted_by_skew [lsort -command _pdds_sort_by_skew $records]
    puts $fp "Top 10 Ports By Clock Skew"
    puts $fp [format "%-6s %-40s %14s %18s %14s %-20s %-20s" "Rank" "Port" "Slack" "DataPathDelay" "ClockSkew" "PathGroup" "View"]
    puts $fp [string repeat "-" 140]
    set rank 1
    foreach record $sorted_by_skew {
        if {$rank > 10} {
            break
        }
        if {![string is double -strict [_pdds_metric_value $record clock_skew]]} {
            continue
        }
        puts $fp [format "%-6d %-40s %14s %18s %14s %-20s %-20s" \
            $rank \
            [_pdds_metric_value $record port_name] \
            [_pdds_format_value [_pdds_metric_value $record slack]] \
            [_pdds_format_value [_pdds_metric_value $record data_path_delay]] \
            [_pdds_format_value [_pdds_metric_value $record clock_skew]] \
            [_pdds_metric_value $record path_group] \
            [_pdds_metric_value $record view_name]]
        incr rank
    }
    if {$rank == 1} {
        puts $fp "  NA"
    }
    puts $fp ""

    puts $fp "Details Sorted By Port Name"
    puts $fp [format "%-40s %-10s %14s %18s %14s %-20s %-20s %-40s %-40s %-20s %-20s %s" \
        "Port" "Status" "Slack" "DataPathDelay" "ClockSkew" "PathGroup" "View" "Startpoint" "Endpoint" "LaunchClock" "CaptureClock" "Message"]
    puts $fp [string repeat "-" 280]
    foreach record $sorted_records {
        puts $fp [format "%-40s %-10s %14s %18s %14s %-20s %-20s %-40s %-40s %-20s %-20s %s" \
            [_pdds_metric_value $record port_name] \
            [_pdds_metric_value $record status] \
            [_pdds_format_value [_pdds_metric_value $record slack]] \
            [_pdds_format_value [_pdds_metric_value $record data_path_delay]] \
            [_pdds_format_value [_pdds_metric_value $record clock_skew]] \
            [_pdds_metric_value $record path_group] \
            [_pdds_metric_value $record view_name] \
            [_pdds_metric_value $record startpoint] \
            [_pdds_metric_value $record endpoint] \
            [_pdds_metric_value $record launch_clock] \
            [_pdds_metric_value $record capture_clock] \
            [_pdds_metric_value $record message]]
    }

    close $fp
}

proc report_port_data_delay_skew {args} {
    set view_name ""
    set out_dir "."
    set prefix "port_data_delay_skew"
    set delay_type "late"
    set input_file ""
    set output_file ""
    set debug_mode 0

    set idx 0
    while {$idx < [llength $args]} {
        set opt [lindex $args $idx]
        incr idx

        switch -- $opt {
            -view {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set view_name [lindex $args $idx]
                incr idx
            }
            -out_dir {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set out_dir [lindex $args $idx]
                incr idx
            }
            -prefix {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set prefix [lindex $args $idx]
                incr idx
            }
            -delay_type {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set delay_type [string tolower [lindex $args $idx]]
                incr idx
            }
            -input_file {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set input_file [lindex $args $idx]
                incr idx
            }
            -output_file {
                if {$idx >= [llength $args]} {
                    error [_pdds_usage]
                }
                set output_file [lindex $args $idx]
                incr idx
            }
            -debug {
                set debug_mode 1
            }
            -help {
                puts [_pdds_usage]
                return
            }
            default {
                error "Unknown option '$opt'. [_pdds_usage]"
            }
        }
    }

    if {[lsearch -exact {late early} $delay_type] < 0} {
        error "-delay_type must be late or early. [_pdds_usage]"
    }

    file mkdir $out_dir

    set file_suffix ""
    if {$view_name ne ""} {
        set file_suffix ".[_pdds_sanitize_filename_part $view_name]"
    }

    if {$input_file eq ""} {
        set input_file [_pdds_join_path $out_dir "${prefix}${file_suffix}.input.rpt"]
    }
    if {$output_file eq ""} {
        set output_file [_pdds_join_path $out_dir "${prefix}${file_suffix}.output.rpt"]
    }

    catch {unset _pdds_clock_source_cache_ready}
    _pdds_build_clock_source_cache

    set port_limit 0
    if {$debug_mode} {
        set port_limit 20
        puts "report_port_data_delay_skew: debug mode enabled, limiting each direction to 20 non-clock port(s)."
    }

    puts "report_port_data_delay_skew: scanning input ports..."
    set input_result [_pdds_scan_ports [all_inputs] input $view_name $delay_type $port_limit]
    set input_stats [_pdds_metric_value $input_result stats]
    set input_records [_pdds_metric_value $input_result records]

    puts "report_port_data_delay_skew: scanning output ports..."
    set output_result [_pdds_scan_ports [all_outputs] output $view_name $delay_type $port_limit]
    set output_stats [_pdds_metric_value $output_result stats]
    set output_records [_pdds_metric_value $output_result records]

    _pdds_write_report $input_file input $view_name $delay_type $input_stats $input_records
    _pdds_write_report $output_file output $view_name $delay_type $output_stats $output_records

    puts "report_port_data_delay_skew input report : $input_file"
    puts "report_port_data_delay_skew output report: $output_file"
    puts "report_port_data_delay_skew input reported/skipped/no_path/error : [_pdds_metric_value $input_stats reported]/[_pdds_metric_value $input_stats clock_skip]/[_pdds_metric_value $input_stats no_path]/[_pdds_metric_value $input_stats error]"
    puts "report_port_data_delay_skew output reported/skipped/no_path/error: [_pdds_metric_value $output_stats reported]/[_pdds_metric_value $output_stats clock_skip]/[_pdds_metric_value $output_stats no_path]/[_pdds_metric_value $output_stats error]"

    return [list \
        input_file $input_file \
        output_file $output_file \
        input_stats $input_stats \
        output_stats $output_stats \
        debug $debug_mode]
}
