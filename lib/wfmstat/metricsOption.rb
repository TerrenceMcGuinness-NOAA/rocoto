##########################################
#
# Module WFMStat
#
##########################################
module WFMStat

  ##########################################  
  #
  # Class MetricsOption
  # 
  ##########################################
  class MetricsOption

    require 'optparse'
    require 'pp'                      
    
    attr_reader :database, :workflowdoc, :verbose, :user_stats, :system_stats, :threads, :processes, :refresh, :refresh_interval, :zombies, :detailed_workflows

    ##########################################  
    #
    # Initialize
    #
    ##########################################
    def initialize(args,name,action)

      @user_stats = false
      @system_stats = false 
      @threads = false
      @processes = false
      @zombies = false
      @detailed_workflows = false
      @refresh = false
      @refresh_interval = 5
      @name = name
      @action = action
      @database = nil
      @workflowdoc = nil
      @verbose = 1
      parse(args)

    end  # initialize

  private

    ##########################################
    #
    # parse
    #
    ##########################################
    def parse(args)

      opts = OptionParser.new do |opts|
        add_opts(opts)
      end

      begin
        opts.parse!(args)
      rescue OptionParser::InvalidOption => e
        puts "ERROR: #{e.message}"
        puts
        puts opts
        Process.exit(1)
      rescue OptionParser::MissingArgument => e
        puts "ERROR: #{e.message}"
        puts
        puts opts
        Process.exit(1)
      end

    end

    ##########################################  
    #
    # add_opts
    #
    ##########################################
    def add_opts(opts)

      # Command usage text
      opts.banner = "Usage:  #{@name} [-h] [-v #] [-d database_file] [-w workflow_document] [-u] [-s] [-t] [-p] [-z] [-W] [-r] [-i SECONDS]"
      
      # Handle option for specifying the database file (optional)
      opts.on("-d","--database PATH",String,"Path to database store file (optional)") do |db|
        @database=db
      end

      # Handle option for specifying the workflow document (optional)
      opts.on("-w","--workflow PATH",String,"Path to workflow document (optional)") do |doc|
        @workflowdoc=doc
      end

      # Handle option for help
      opts.on("-h","--help","Show this message") do
        puts opts
        Process.exit(0)
      end

      # Handle option for verbose
      opts.on("-v","--verbose [LEVEL]",/^[0-9]+$/,"Run in verbose mode") do |verbose|
        if verbose.nil?
          @verbose=1
        else
          @verbose=verbose.to_i
        end
      end

      # User statistics
      opts.on("-u","--user-stats","Show per-user daemon statistics") do 
        @user_stats = true
      end

      # System statistics
      opts.on("-s","--system-stats","Show system-wide daemon statistics") do
        @system_stats = true
      end

      # Thread information
      opts.on("-t","--threads","Show thread information for daemons") do
        @threads = true
      end

      # Process information  
      opts.on("-p","--processes","Show detailed process information") do
        @processes = true
      end

      # Zombie process detection
      opts.on("-z","--zombies","Show zombie process information") do
        @zombies = true
      end

      # Detailed workflow breakdown
      opts.on("-W","--detailed-workflows","Force detailed per-workflow breakdown") do
        @detailed_workflows = true
      end

      # Refresh mode
      opts.on("-r","--refresh","Continuously refresh display") do
        @refresh = true
      end

      # Refresh interval
      opts.on("-i","--interval SECONDS",Integer,"Refresh interval in seconds (default: 5)") do |interval|
        @refresh_interval = interval
      end

    end # add_opts

  end  # Class MetricsOption

end  # Module WFMStat
