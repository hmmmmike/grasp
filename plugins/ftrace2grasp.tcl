#
# Convert a trace from FTrace (sched_switch) to Grasp format
#
# FTrace: http://www.mjmwired.net/kernel/Documentation/trace/ftrace.txt
#
# IMPORTANT: This converter works with traces generated by Ftrace with the following settings
# inside the iter_ctrl configuration file (usually located in /sys/kernel/debug/tracing/):
#
# print-parent nosym-offset nosym-addr noverbose noraw nohex nobin noblock nostacktrace nosched-tree
#

# enable the conversion from the command line
addTraceFormat ftrace "Ftrace::convert"

namespace eval Ftrace {
  proc convert {fileInName} {
    set fileOutName [file root $fileInName].grasp
    
    set fileIn [open $fileInName r]
    
    array set names {}
    set timeOffset 0
    set events ""
    
    while {![eof $fileIn]} {
      set line [gets $fileIn]
      
      # trim all leading and trailing spaces
      set line [string trim $line " "]
    
      # skip empty lines
      if {![llength $line]} continue
    
      # skip lines starting with #
      if {[string index $line 0] eq "#"} continue
    
      # get the taskIn and taskOut
      if {![regexp {([0-9]+):[ 0-9]+:[SR] *==>.*?([0-9]+):[ 0-9]+:} $line _ taskOut taskIn]} continue

      # get the task name from the first string
      set taskName [lindex $line 0]
      set task [lindex [split $taskName "-"] end]
      set taskName [join [lrange [split $taskName "-"] 0 end-1] "-"]
      set names($task) $taskName
      
      # get the time
      set time [string trim [lindex $line 2] ":"]
      if {$timeOffset == 0} { set timeOffset $time }
      
      set time [expr $time - $timeOffset]
      append events "plot $time jobPreempted $taskOut.job -target $taskIn.job\n"
      append events "plot $time jobResumed $taskIn.job\n"
    }
    
    close $fileIn
    
    # write the Grasp trace
    set fileOut [open $fileOutName w+]
    puts $fileOut "#\n# This trace was automatically generated from an Ftrace trace by Grasp (version $::grasp_version)\n#"
    foreach {task name} [array get names] {
      puts $fileOut "newTask $task -name \"$name\""
      puts $fileOut "newJob $task.job $task -name \"\[$task name\]\""
      puts $fileOut "plot 0 jobStarted $task.job"
    }
    puts $fileOut $events
    close $fileOut
    
    return $fileOutName
  }
}