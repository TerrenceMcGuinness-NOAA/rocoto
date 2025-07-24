#!/usr/bin/ruby

# Get the base directory of the WFM installation
__WFMDIR__=File.expand_path("../../",__FILE__)

# Add include paths for WFM and required libraries
$:.unshift("#{__WFMDIR__}/lib")
$:.unshift("#{__WFMDIR__}/lib/sqlite3-ruby")
$:.unshift("#{__WFMDIR__}/lib/libxml-ruby")
$:.unshift("#{__WFMDIR__}/lib/thread/lib")

# Load minimal dependencies for metrics functionality
require 'wfmstat/metricsengine'
require 'wfmstat/metricsOption'

# Create workflow metrics engine and run it
opt=WFMStat::MetricsOption.new(ARGV,'rocotometrics','metrics')
metricsEngine=WFMStat::MetricsEngine.new(opt)
metricsEngine.wfmmetrics
