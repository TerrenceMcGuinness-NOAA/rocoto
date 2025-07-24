##########################################
#
# Module WFMStat
#
##########################################
module WFMStat

  require 'set'

  ##########################################
  #
  # Class MetricsEngine
  #
  ##########################################
  class MetricsEngine

    ##########################################
    #
    # initialize
    #
    ##########################################
    def initialize(options)

      begin

        # Store the options
        @options = options

        # Disable garbage collection for performance
        GC.disable

        # Initialize metrics collection
        @daemon_processes = {}
        @zombie_processes = []
        @system_metrics = {}

      rescue => crash
        STDERR.puts(crash.message)
        STDERR.puts(crash.backtrace.join("\n"))
        Process.exit(1)
      end

    end

    ##########################################
    #
    # wfmmetrics - main entry point
    #
    ##########################################
    def wfmmetrics

      begin

        if @options.refresh
          # Continuous refresh mode
          loop do
            # Clear screen
            system('clear') || system('cls')
            
            # Show timestamp
            puts "Rocoto Daemon Metrics - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
            puts "Refresh interval: #{@options.refresh_interval} seconds (Press Ctrl+C to exit)"
            puts

            # Collect and display metrics
            display_metrics

            # Wait for refresh interval
            sleep @options.refresh_interval
          end
        else
          # Single display mode
          display_metrics
        end

      rescue Interrupt
        puts "\nExiting rocotometrics..."
        exit 0
      rescue => crash
        WorkflowMgr.stderr("#{crash.message}", 1)
        if @options.verbose >= 1
          WorkflowMgr.stderr(crash.backtrace.join("\n"), 1)
          WorkflowMgr.log(crash.backtrace.join("\n"))
        end
        Process.exit(1)
      end

    end

  private

    ##########################################
    #
    # display_metrics
    #
    ##########################################
    def display_metrics

      # Collect daemon process information
      collect_daemon_processes

      # Display requested metrics
      if @options.user_stats
        display_user_stats
      end

      if @options.system_stats
        display_system_stats
      end

      if @options.threads
        display_thread_info
      end

      if @options.processes
        display_process_info
      end

      if @options.zombies
        display_zombie_info
      end

      # Show database metrics if database is available
      if @options.database && File.exist?(@options.database)
        display_database_metrics
      end

      # Verbose dashboard mode - show comprehensive overview
      if @options.verbose >= 2
        display_verbose_dashboard
      # If no specific options, show summary
      elsif !@options.user_stats && !@options.system_stats && !@options.threads && !@options.processes && !@options.zombies
        display_summary
      end

    end

    ##########################################
    #
    # collect_daemon_processes
    #
    ##########################################
    def collect_daemon_processes

      @daemon_processes = {
        'rocotobqserver' => [],
        'rocotodbserver' => [],
        'rocotoioserver' => []
      }
      
      # Clear previous zombie list
      @zombie_processes = []

      # Use ps to find all rocoto daemon processes including state information
      ['rocotobqserver', 'rocotodbserver', 'rocotoioserver'].each do |daemon_type|
        # Include 'stat' field to detect zombie processes
        output = `ps -eo pid,ppid,user,stat,thcount,nlwp,rss,vsz,pcpu,pmem,etime,cmd | grep #{daemon_type} | grep -v grep`
        
        output.each_line do |line|
          fields = line.strip.split(/\s+/, 12)
          next if fields.length < 12

          process_info = {
            :pid => fields[0].to_i,
            :ppid => fields[1].to_i,
            :user => fields[2],
            :stat => fields[3],        # Process state
            :threads => fields[4].to_i,
            :lwp => fields[5].to_i,
            :rss => fields[6].to_i,    # Resident Set Size (KB)
            :vsz => fields[7].to_i,    # Virtual Size (KB)
            :pcpu => fields[8].to_f,   # CPU percentage
            :pmem => fields[9].to_f,   # Memory percentage
            :etime => fields[10],      # Elapsed time
            :cmd => fields[11],        # Command line
            :daemon_type => daemon_type,
            :is_zombie => false
          }

          # Check if process is a zombie using ps stat field
          if fields[3].include?('Z')
            process_info[:is_zombie] = true
            @zombie_processes << process_info
          else
            # Double-check using /proc filesystem (Rocoto's method)
            process_info[:is_zombie] = check_zombie_status(fields[0].to_i)
            if process_info[:is_zombie]
              @zombie_processes << process_info
            end
          end

          @daemon_processes[daemon_type] << process_info
        end
      end

    end

    ##########################################
    #
    # check_zombie_status - Use Rocoto's zombie detection method
    #
    ##########################################
    def check_zombie_status(pid)

      begin
        if RUBY_PLATFORM =~ /linux/
          # Use /proc filesystem to check process state (Rocoto's method)
          status_file = "/proc/#{pid}/status"
          return false unless File.exist?(status_file)
          
          status_content = IO.readlines(status_file, nil)[0]
          return false unless status_content
          
          state_match = status_content.match(/^State:\s+(\w)/)
          return false unless state_match
          
          return state_match[1] == "Z"
        else
          # Fallback method for non-Linux systems
          system("ps -eo pid,stat | grep Z | grep #{pid} 2>&1 > /dev/null")
          return $?.exitstatus == 0
        end
      rescue => e
        # If we can't determine status, assume not zombie
        return false
      end

    end

    ##########################################
    #
    # display_summary
    #
    ##########################################
    def display_summary

      puts "=" * 80
      puts "Rocoto Daemon Metrics Summary"
      puts "=" * 80
      puts

      total_daemons = 0
      total_threads = 0
      total_memory = 0
      users = Set.new

      @daemon_processes.each do |daemon_type, processes|
        count = processes.length
        threads = processes.sum { |p| p[:threads] }
        memory_mb = processes.sum { |p| p[:rss] } / 1024.0
        process_users = processes.map { |p| p[:user] }.uniq

        puts sprintf("%-16s: %3d processes, %4d threads, %6.1f MB RAM",
                    daemon_type, count, threads, memory_mb)

        total_daemons += count
        total_threads += threads
        total_memory += memory_mb
        users.merge(process_users)
      end

      puts "-" * 60
      puts sprintf("%-16s: %3d processes, %4d threads, %6.1f MB RAM",
                  "TOTAL", total_daemons, total_threads, total_memory)
      puts
      puts "Active users running daemons: #{users.size}"
      puts "Users: #{users.to_a.sort.join(', ')}" if users.size > 0
      
      # Display zombie information
      if @zombie_processes.length > 0
        puts
        puts "⚠️  WARNING: ZOMBIE PROCESSES DETECTED"
        puts "=" * 40
        @zombie_processes.each do |zombie|
          puts sprintf("ZOMBIE: PID %d (%s) - %s owned by %s", 
                      zombie[:pid], zombie[:daemon_type], zombie[:stat], zombie[:user])
        end
        puts "=" * 40
        puts "Total zombie processes: #{@zombie_processes.length}"
      else
        puts
        puts "✓ No zombie processes detected"
      end
      puts

    end

    ##########################################
    #
    # display_user_stats
    #
    ##########################################
    def display_user_stats

      puts "=" * 80
      puts "Per-User Daemon Statistics"
      puts "=" * 80
      puts

      user_stats = {}
      user_workflows = {}
      user_workflow_details = {}

      @daemon_processes.each do |daemon_type, processes|
        processes.each do |process|
          user = process[:user]
          user_stats[user] ||= { :processes => 0, :threads => 0, :memory => 0, :daemons => {} }
          user_stats[user][:processes] += 1
          user_stats[user][:threads] += process[:threads]
          user_stats[user][:memory] += process[:rss] / 1024.0
          user_stats[user][:daemons][daemon_type] ||= 0
          user_stats[user][:daemons][daemon_type] += 1
          
          # Extract workflow XML file from command line
          xml_file = extract_workflow_xml(process[:cmd])
          if xml_file
            user_workflows[user] ||= Set.new
            user_workflows[user].add(xml_file)
            
            # Track detailed stats per workflow
            user_workflow_details[user] ||= {}
            user_workflow_details[user][xml_file] ||= { :processes => 0, :threads => 0, :memory => 0, :daemons => {} }
            user_workflow_details[user][xml_file][:processes] += 1
            user_workflow_details[user][xml_file][:threads] += process[:threads]
            user_workflow_details[user][xml_file][:memory] += process[:rss] / 1024.0
            user_workflow_details[user][xml_file][:daemons][daemon_type] ||= 0
            user_workflow_details[user][xml_file][:daemons][daemon_type] += 1
          end
        end
      end

      # Check if any user has multiple workflows or if detailed view is forced
      has_multiple_workflows = user_workflows.any? { |user, workflows| workflows.size > 1 }
      force_detailed = @options.detailed_workflows

      if has_multiple_workflows || force_detailed
        display_detailed_workflow_stats(user_stats, user_workflow_details)
      else
        display_compact_workflow_stats(user_stats, user_workflows)
      end

    end

    ##########################################
    #
    # display_compact_workflow_stats - Single workflow per user
    #
    ##########################################
    def display_compact_workflow_stats(user_stats, user_workflows)
      
      format = "%-12s %8s %8s %10s %10s %10s %10s %-20s\n"
      puts sprintf(format, "USER", "PROC", "THREADS", "MEMORY_MB", "BQSERVER", "DBSERVER", "IOSERVER", "WORKFLOW_XML")
      puts "-" * 100

      user_stats.sort.each do |user, stats|
        workflow_list = user_workflows[user] ? user_workflows[user].to_a.join(", ") : "N/A"
        puts sprintf(format,
                    user,
                    stats[:processes],
                    stats[:threads],
                    sprintf("%.1f", stats[:memory]),
                    stats[:daemons]['rocotobqserver'] || 0,
                    stats[:daemons]['rocotodbserver'] || 0,
                    stats[:daemons]['rocotoioserver'] || 0,
                    workflow_list)
      end
      puts

    end

    ##########################################
    #
    # display_detailed_workflow_stats - Multiple workflows per user
    #
    ##########################################
    def display_detailed_workflow_stats(user_stats, user_workflow_details)
      
      total_workflows = user_workflow_details.values.map(&:keys).flatten.uniq.size
      puts "Pipeline/Multi-workflow mode - showing detailed per-workflow breakdown:"
      puts "Total unique workflows detected: #{total_workflows}"
      puts
      
      user_stats.sort.each do |user, stats|
        puts sprintf("User: %-12s [%d processes, %d threads, %.1f MB total]", 
                    user, stats[:processes], stats[:threads], stats[:memory])
        
        if user_workflow_details[user]
          workflow_count = user_workflow_details[user].size
          puts sprintf("  Running %d workflow%s:", workflow_count, workflow_count == 1 ? "" : "s")
          
          user_workflow_details[user].sort.each do |workflow, wf_stats|
            # Calculate daemon breakdown
            daemon_info = []
            daemon_info << "BQ:#{wf_stats[:daemons]['rocotobqserver'] || 0}" if (wf_stats[:daemons]['rocotobqserver'] || 0) > 0
            daemon_info << "DB:#{wf_stats[:daemons]['rocotodbserver'] || 0}" if (wf_stats[:daemons]['rocotodbserver'] || 0) > 0  
            daemon_info << "IO:#{wf_stats[:daemons]['rocotoioserver'] || 0}" if (wf_stats[:daemons]['rocotoioserver'] || 0) > 0
            
            puts sprintf("  ├─ %-20s: %2d processes, %2d threads, %5.1f MB [%s]",
                        workflow,
                        wf_stats[:processes],
                        wf_stats[:threads],
                        wf_stats[:memory],
                        daemon_info.join(" "))
          end
        end
        puts
      end

    end

    ##########################################
    #
    # display_system_stats
    #
    ##########################################
    def display_system_stats

      puts "=" * 80
      puts "System-Wide Daemon Statistics"
      puts "=" * 80
      puts

      # Collect system load and memory information
      if File.exist?("/proc/loadavg")
        loadavg = File.read("/proc/loadavg").strip.split
        puts sprintf("System Load: %.2f %.2f %.2f", loadavg[0].to_f, loadavg[1].to_f, loadavg[2].to_f)
      end

      if File.exist?("/proc/meminfo")
        meminfo = {}
        File.readlines("/proc/meminfo").each do |line|
          key, value = line.split(":")
          meminfo[key.strip] = value.strip.split[0].to_i if value
        end

        if meminfo["MemTotal"] && meminfo["MemAvailable"]
          total_gb = meminfo["MemTotal"] / 1024.0 / 1024.0
          avail_gb = meminfo["MemAvailable"] / 1024.0 / 1024.0
          used_gb = total_gb - avail_gb
          puts sprintf("System Memory: %.1f GB total, %.1f GB used, %.1f GB available",
                      total_gb, used_gb, avail_gb)
        end
      end
      puts

      # Show daemon distribution across the system
      total_processes = @daemon_processes.values.flatten.length
      puts "Daemon Process Distribution:"

      @daemon_processes.each do |daemon_type, processes|
        avg_cpu = processes.empty? ? 0 : processes.sum { |p| p[:pcpu] } / processes.length
        avg_mem = processes.empty? ? 0 : processes.sum { |p| p[:pmem] } / processes.length
        total_rss = processes.sum { |p| p[:rss] } / 1024.0

        puts sprintf("  %-16s: %3d instances, avg CPU: %5.1f%%, avg MEM: %5.1f%%, total: %6.1f MB",
                    daemon_type, processes.length, avg_cpu, avg_mem, total_rss)
      end
      puts

    end

    ##########################################
    #
    # display_thread_info
    #
    ##########################################
    def display_thread_info

      puts "=" * 80
      puts "Thread Information for Rocoto Daemons"  
      puts "=" * 80
      puts

      format = "%-8s %-12s %-16s %8s %8s %10s %10s %8s\n"
      puts sprintf(format, "PID", "USER", "DAEMON_TYPE", "THREADS", "LWP", "RSS_MB", "ETIME", "STATUS")
      puts "-" * 88

      @daemon_processes.each do |daemon_type, processes|
        processes.sort_by { |p| p[:threads] }.reverse.each do |process|
          status = process[:is_zombie] ? "ZOMBIE" : "NORMAL"
          status_marker = process[:is_zombie] ? "⚠️ " : "  "
          
          puts sprintf("#{status_marker}#{format}",
                      process[:pid],
                      process[:user],
                      daemon_type,
                      process[:threads],
                      process[:lwp],
                      sprintf("%.1f", process[:rss] / 1024.0),
                      process[:etime],
                      status)
        end
      end
      
      zombie_count = @daemon_processes.values.flatten.count { |p| p[:is_zombie] }
      if zombie_count > 0
        puts
        puts "⚠️  #{zombie_count} zombie process(es) detected - use -z for detailed zombie analysis"
      end
      puts

    end

    ##########################################
    #
    # display_process_info
    #
    ##########################################
    def display_process_info

      puts "=" * 120
      puts "Detailed Process Information for Rocoto Daemons"
      puts "=" * 120
      puts

      format = "%-8s %-8s %-12s %-16s %6s %6s %8s %8s %6s %6s %-10s\n"
      puts sprintf(format, "PID", "PPID", "USER", "DAEMON_TYPE", "THR", "LWP", "RSS_MB", "VSZ_MB", "%CPU", "%MEM", "ETIME")
      puts "-" * 120

      all_processes = @daemon_processes.values.flatten
      all_processes.sort_by { |p| [p[:user], p[:daemon_type], p[:pid]] }.each do |process|
        puts sprintf(format,
                    process[:pid],
                    process[:ppid],
                    process[:user],
                    process[:daemon_type],
                    process[:threads],
                    process[:lwp],
                    sprintf("%.1f", process[:rss] / 1024.0),
                    sprintf("%.1f", process[:vsz] / 1024.0),
                    sprintf("%.1f", process[:pcpu]),
                    sprintf("%.1f", process[:pmem]),
                    process[:etime])
      end
      puts

    end

    ##########################################
    #
    # display_database_metrics
    #
    ##########################################
    def display_database_metrics

      begin
        require 'sqlite3'
        
        puts "=" * 80
        puts "Database Performance Metrics"
        puts "=" * 80
        puts "Database: #{@options.database}"
        puts

        db = SQLite3::Database.new(@options.database)
        
        # Get database size
        db_size = File.size(@options.database) / 1024.0 / 1024.0
        puts sprintf("Database size: %.2f MB", db_size)

        # Get job statistics
        job_count = db.get_first_value("SELECT COUNT(*) FROM jobs")
        puts "Total jobs in database: #{job_count}"

        # Get recent job performance stats
        recent_jobs = db.execute("SELECT AVG(duration), COUNT(*) FROM jobs WHERE duration > 0 AND rowid > (SELECT MAX(rowid) FROM jobs) - 1000")
        if recent_jobs[0][0]
          avg_duration = recent_jobs[0][0] / 60.0  # Convert to minutes
          recent_count = recent_jobs[0][1]
          puts sprintf("Recent jobs (last 1000): %d jobs, avg duration: %.1f minutes", recent_count, avg_duration)
        end

        # Get active job count
        active_jobs = db.get_first_value("SELECT COUNT(*) FROM jobs WHERE state IN ('QUEUED', 'RUNNING')")
        puts "Currently active jobs: #{active_jobs}"

        db.close
        puts

      rescue => e
        puts "Unable to read database metrics: #{e.message}" if @options.verbose >= 1
      end

    end

    ##########################################
    #
    # display_zombie_info
    #
    ##########################################
    def display_zombie_info

      puts "=" * 80
      puts "Zombie Process Detection"
      puts "=" * 80
      puts

      if @zombie_processes.length > 0
        puts "⚠️  WARNING: ZOMBIE ROCOTO DAEMONS DETECTED"
        puts "=" * 50
        puts

        format = "%-8s %-12s %-16s %-8s %-10s %-20s\n"
        puts sprintf(format, "PID", "USER", "DAEMON_TYPE", "STAT", "ETIME", "COMMAND")
        puts "-" * 80

        @zombie_processes.each do |zombie|
          puts sprintf(format,
                      zombie[:pid],
                      zombie[:user],
                      zombie[:daemon_type],
                      zombie[:stat],
                      zombie[:etime],
                      zombie[:cmd].length > 20 ? zombie[:cmd][0..17] + "..." : zombie[:cmd])
        end

        puts
        puts "=" * 50
        puts "Total zombie processes found: #{@zombie_processes.length}"
        puts
        puts "RECOMMENDED ACTIONS:"
        puts "1. Check parent processes that may have failed to reap child processes"
        puts "2. Consider restarting affected Rocoto workflows"
        puts "3. Monitor system for accumulating zombie processes"
        puts "4. Check system logs for related errors"
        
        # Group zombies by user for specific recommendations
        zombie_users = @zombie_processes.group_by { |z| z[:user] }
        if zombie_users.size > 1
          puts "5. Zombies affect multiple users: #{zombie_users.keys.join(', ')}"
        end
        
        # Check for long-running zombies
        old_zombies = @zombie_processes.select { |z| z[:etime].include?('-') }  # Day+ old
        if old_zombies.length > 0
          puts "6. #{old_zombies.length} zombie(s) are over 1 day old - urgent attention needed"
        end

      else
        puts "✓ No zombie Rocoto daemon processes detected"
        puts
        puts "All Rocoto daemons are healthy:"
        total_processes = @daemon_processes.values.flatten.length
        puts "  • #{total_processes} active daemon processes found"
        puts "  • All processes are in normal running states"
        puts "  • No zombie or orphaned processes detected"
        
        if total_processes == 0
          puts
          puts "Note: No Rocoto daemons are currently running on this system."
          puts "This is normal if no workflows are active."
        end
      end

      puts

    end

    ##########################################
    #
    # display_verbose_dashboard - Comprehensive overview of all metrics
    #
    ##########################################
    def display_verbose_dashboard
      
      puts "=" * 100
      puts "ROCOTO COMPREHENSIVE DASHBOARD (Verbose Mode)"
      puts "=" * 100
      puts "Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts

      # 1. Executive Summary
      total_processes = @daemon_processes.values.flatten.length
      total_threads = @daemon_processes.values.flatten.sum { |p| p[:threads] }
      total_memory = @daemon_processes.values.flatten.sum { |p| p[:rss] } / 1024.0
      
      puts "📊 EXECUTIVE SUMMARY"
      puts "-" * 50
      puts sprintf("Total Daemon Processes: %d", total_processes)
      puts sprintf("Total Threads:          %d", total_threads) 
      puts sprintf("Total Memory Usage:     %.1f MB", total_memory)
      puts sprintf("Active Users:           %d", get_active_users.size)
      puts sprintf("Zombie Status:          %s", @zombie_processes.empty? ? "✓ All Healthy" : "⚠ #{@zombie_processes.size} zombies detected")
      puts

      # 2. Per-Daemon Breakdown
      puts "🔧 DAEMON TYPE BREAKDOWN"
      puts "-" * 50
      ['rocotobqserver', 'rocotodbserver', 'rocotoioserver'].each do |daemon_type|
        processes = @daemon_processes[daemon_type]
        if processes.length > 0
          daemon_memory = processes.sum { |p| p[:rss] } / 1024.0
          daemon_threads = processes.sum { |p| p[:threads] }
          puts sprintf("%-15s: %2d processes, %3d threads, %6.1f MB", 
                      daemon_type, processes.length, daemon_threads, daemon_memory)
        else
          puts sprintf("%-15s: %2d processes (inactive)", daemon_type, 0)
        end
      end
      puts

      # 3. Workflow Analysis
      puts "📋 WORKFLOW ANALYSIS"
      puts "-" * 50
      workflow_stats = analyze_workflows
      if workflow_stats.empty?
        puts "No active workflows detected"
      else
        puts sprintf("Active Workflows: %d", workflow_stats.size)
        workflow_stats.sort.each do |workflow, stats|
          puts sprintf("├─ %-20s: %d processes, %.1f MB", 
                      workflow, stats[:processes], stats[:memory])
        end
      end
      puts

      # 4. User Resource Distribution
      puts "👥 USER RESOURCE DISTRIBUTION"
      puts "-" * 50
      user_stats = calculate_user_stats
      if user_stats.empty?
        puts "No users running daemons"
      else
        user_stats.sort.each do |user, stats|
          puts sprintf("%-12s: %2d proc, %3d threads, %6.1f MB", 
                      user, stats[:processes], stats[:threads], stats[:memory])
        end
      end
      puts

      # 5. System Health Check
      puts "🏥 SYSTEM HEALTH CHECK"
      puts "-" * 50
      health_issues = []
      
      # Check for zombies
      if @zombie_processes.length > 0
        health_issues << "#{@zombie_processes.length} zombie processes detected"
      end
      
      # Check for resource usage
      if total_memory > 1000  # > 1GB
        health_issues << "High memory usage (#{total_memory.round(1)} MB)"
      end
      
      # Check for too many processes per user
      user_stats.each do |user, stats|
        if stats[:processes] > 10
          health_issues << "User #{user} has many processes (#{stats[:processes]})"
        end
      end
      
      if health_issues.empty?
        puts "✓ All systems healthy"
        puts "✓ No performance concerns detected"
        puts "✓ Resource usage within normal limits"
      else
        puts "⚠ Health Issues Detected:"
        health_issues.each { |issue| puts "  • #{issue}" }
      end
      puts

      # 6. Database Status (if available)
      if @options.database && File.exist?(@options.database)
        puts "💾 DATABASE STATUS"
        puts "-" * 50
        db_size = File.size(@options.database) / 1024.0 / 1024.0
        puts sprintf("Database file: %s", File.basename(@options.database))
        puts sprintf("Database size: %.2f MB", db_size)
        puts sprintf("Last modified: %s", File.mtime(@options.database).strftime('%Y-%m-%d %H:%M:%S'))
        puts
      end

      puts "=" * 100
      puts "End of Comprehensive Dashboard"
      puts "=" * 100

    end

    ##########################################
    #
    # Helper methods for verbose dashboard
    #
    ##########################################
    
    def get_active_users
      users = Set.new
      @daemon_processes.values.flatten.each { |p| users.add(p[:user]) }
      users
    end
    
    def analyze_workflows
      workflow_stats = {}
      @daemon_processes.values.flatten.each do |process|
        xml_file = extract_workflow_xml(process[:cmd])
        if xml_file
          workflow_stats[xml_file] ||= { :processes => 0, :memory => 0 }
          workflow_stats[xml_file][:processes] += 1
          workflow_stats[xml_file][:memory] += process[:rss] / 1024.0
        end
      end
      workflow_stats
    end
    
    def calculate_user_stats
      user_stats = {}
      @daemon_processes.values.flatten.each do |process|
        user = process[:user]
        user_stats[user] ||= { :processes => 0, :threads => 0, :memory => 0 }
        user_stats[user][:processes] += 1
        user_stats[user][:threads] += process[:threads]
        user_stats[user][:memory] += process[:rss] / 1024.0
      end
      user_stats
    end

    ##########################################
    #
    # extract_workflow_xml - Extract XML filename from command line
    #
    ##########################################
    def extract_workflow_xml(cmd_line)
      
      return nil if cmd_line.nil? || cmd_line.empty?
      
      # Split command line into arguments
      args = cmd_line.strip.split(/\s+/)
      
      # For rocoto daemons, the XML file is typically the 4th argument (index 3)
      # Command pattern: rocotobqserver [parent_pid] [verbosity] [workflow_xml] [pipe_fd]
      if args.length >= 4
        potential_xml = args[3]
        
        # Check if it looks like an XML file
        if potential_xml.end_with?('.xml')
          # Return just the filename, not the full path
          return File.basename(potential_xml)
        end
      end
      
      # Fallback: look for any .xml file in the command line
      args.each do |arg|
        if arg.end_with?('.xml')
          return File.basename(arg)
        end
      end
      
      return nil
    end

  end

end
