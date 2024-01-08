proc custom_ip_files {ip_name ip_files} {
  set proj_fileset [get_filesets sources_1]

  foreach m_file_and_lib $ip_files {
    puts "foreach loop:"
    puts $m_file_and_lib
    #puts
    set m_file [lindex $m_file_and_lib 0]
    set m_lib  [lindex $m_file_and_lib 1]

    if {[file extension $m_file] eq ".xdc"} {
      add_files -norecurse -fileset constrs_1 $m_file
    } else {
      add_files -norecurse -scan_for_includes -fileset $proj_fileset $m_file
    }

    set_property library $m_lib [get_files $m_file]
  }
  set_property "top" "$ip_name" $proj_fileset
  set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
}
