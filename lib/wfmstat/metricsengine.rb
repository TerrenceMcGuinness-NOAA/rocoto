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
        @system_metrics = {}

      rescue => crash
        WorkflowMgr.log(crash.message)
        WorkflowMgr.log(crash.backtrace.join("\n"))
        WorkflowMgr.stderr(crash.message, 1)
        WorkflowMgr.stderr(crash.backtrace.join("\n"), 1)
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

      # Show database metrics if database is available
      if @options.database && File.exist?(@options.database)
        display_database_metrics
      end

      # If no specific options, show summary
      if !@options.user_stats && !@options.system_stats && !@options.threads && !@options.processes
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

      # Use ps to find all rocoto daemon processes
      ['rocotobqserver', 'rocotodbserver', 'rocotoioserver'].each do |daemon_type|
        output = `ps -eo pid,ppid,user,thcount,nlwp,rss,vsz,pcpu,pmem,etime,cmd | grep #{daemon_type} | grep -v grep`
        
        output.each_line do |line|
          fields = line.strip.split(/\s+/, 11)
          next if fields.length < 11

          process_info = {
            :pid => fields[0].to_i,
            :ppid => fields[1].to_i,
            :user => fields[2],
            :threads => fields[3].to_i,
            :lwp => fields[4].to_i,
            :rss => fields[5].to_i,    # Resident Set Size (KB)
            :vsz => fields[6].to_i,    # Virtual Size (KB)
            :pcpu => fields[7].to_f,   # CPU percentage
            :pmem => fields[8].to_f,   # Memory percentage
            :etime => fields[9],       # Elapsed time
            :cmd => fields[10],        # Command line
            :daemon_type => daemon_type
          }

          @daemon_processes[daemon_type] << process_info
        end
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

      @daemon_processes.each do |daemon_type, processes|
        processes.each do |process|
          user = process[:user]
          user_stats[user] ||= { :processes => 0, :threads => 0, :memory => 0, :daemons => {} }
          user_stats[user][:processes] += 1
          user_stats[user][:threads] += process[:threads]
          user_stats[user][:memory] += process[:rss] / 1024.0
          user_stats[user][:daemons][daemon_type] ||= 0
          user_stats[user][:daemons][daemon_type] += 1
        end
      end

      format = "%-12s %8s %8s %10s %10s %10s %10s\n"
      puts sprintf(format, "USER", "PROC", "THREADS", "MEMORY_MB", "BQSERVER", "DBSERVER", "IOSERVER")
      puts "-" * 80

      user_stats.sort.each do |user, stats|
        puts sprintf(format,
                    user,
                    stats[:processes],
                    stats[:threads],
                    sprintf("%.1f", stats[:memory]),
                    stats[:daemons]['rocotobqserver'] || 0,
                    stats[:daemons]['rocotodbserver'] || 0,
                    stats[:daemons]['rocotoioserver'] || 0)
      end
      puts

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

      format = "%-8s %-12s %-16s %8s %8s %10s %10s\n"
      puts sprintf(format, "PID", "USER", "DAEMON_TYPE", "THREADS", "LWP", "RSS_MB", "ETIME")
      puts "-" * 80

      @daemon_processes.each do |daemon_type, processes|
        processes.sort_by { |p| p[:threads] }.reverse.each do |process|
          puts sprintf(format,
                      process[:pid],
                      process[:user],
                      daemon_type,
                      process[:threads],
                      process[:lwp],
                      sprintf("%.1f", process[:rss] / 1024.0),
                      process[:etime])
        end
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

  end

end
