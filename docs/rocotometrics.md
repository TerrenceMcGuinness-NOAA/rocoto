# rocotometrics - Rocoto Daemon Metrics Utility

## Overview

`rocotometrics` is a system monitoring utility for Rocoto workflow management daemons. It provides real-time insights into daemon processes, resource usage, and system performance metrics.

## Features

- **Process Monitoring**: Track rocotobqserver, rocotodbserver, and rocotoioserver daemons
- **Resource Usage**: Monitor memory consumption, CPU usage, and thread counts
- **User Statistics**: Per-user breakdown of daemon usage
- **System Metrics**: System load, memory usage, and daemon distribution
- **Real-time Monitoring**: Continuous refresh mode with configurable intervals
- **Database Integration**: Optional database performance metrics

## Installation

The utility is included with Rocoto and installed in the `bin/` directory:

```bash
# Make sure rocoto/bin is in your PATH
export PATH="/path/to/rocoto/bin:$PATH"
```

## Usage

### Basic Usage

```bash
# Show summary of all Rocoto daemons
rocotometrics

# Show per-user statistics
rocotometrics -u

# Show system-wide statistics  
rocotometrics -s

# Show thread information
rocotometrics -t

# Show detailed process information
rocotometrics -p
```

### Advanced Usage

```bash
# Combine multiple views
rocotometrics -u -s -t

# Continuous monitoring (refresh every 5 seconds)
rocotometrics -r

# Custom refresh interval (every 2 seconds)
rocotometrics -r -i 2

# Include database metrics (if database available)
rocotometrics -d /path/to/workflow.db -s

# Verbose output
rocotometrics -v 2 -p
```

## Output Examples

### Summary View (Default)
```
================================================================================
Rocoto Daemon Metrics Summary
================================================================================

rocotobqserver  :   3 processes,   39 threads,  115.5 MB RAM
rocotodbserver  :   2 processes,   18 threads,   45.2 MB RAM
rocotoioserver  :   1 processes,    8 threads,   12.1 MB RAM
------------------------------------------------------------
TOTAL           :   6 processes,   65 threads,  172.8 MB RAM

Active users running daemons: 2
Users: user1, user2
```

### User Statistics (-u)
```
================================================================================
Per-User Daemon Statistics
================================================================================

USER             PROC  THREADS  MEMORY_MB   BQSERVER   DBSERVER   IOSERVER
--------------------------------------------------------------------------------
user1               4       42       98.5          2          1          1
user2               2       23       74.3          1          1          0
```

### System Statistics (-s)
```
================================================================================
System-Wide Daemon Statistics  
================================================================================

System Load: 1.25 1.45 1.32
System Memory: 32.0 GB total, 8.5 GB used, 23.5 GB available

Daemon Process Distribution:
  rocotobqserver  :   3 instances, avg CPU:   2.1%, avg MEM:   0.4%, total:  115.5 MB
  rocotodbserver  :   2 instances, avg CPU:   0.8%, avg MEM:   0.2%, total:   45.2 MB
  rocotoioserver  :   1 instances, avg CPU:   0.3%, avg MEM:   0.1%, total:   12.1 MB
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --verbose [LEVEL]` | Verbose output (default: 1) |
| `-d, --database PATH` | Path to database file (optional) |
| `-w, --workflow PATH` | Path to workflow document (optional) |
| `-u, --user-stats` | Show per-user daemon statistics |
| `-s, --system-stats` | Show system-wide daemon statistics |
| `-t, --threads` | Show thread information for daemons |
| `-p, --processes` | Show detailed process information |
| `-r, --refresh` | Continuously refresh display |
| `-i, --interval SECONDS` | Refresh interval (default: 5) |

## Monitored Daemon Types

1. **rocotobqserver** - Batch queue server daemon for performance optimization
2. **rocotodbserver** - Database server daemon for workflow state management  
3. **rocotoioserver** - I/O server daemon for file system operations

## System Requirements

- Linux operating system with `/proc` filesystem
- Ruby with required Rocoto libraries
- Access to process information via `ps` command

## Integration with Rocoto

`rocotometrics` leverages the existing Rocoto infrastructure:

- **Process Discovery**: Uses `ps` to find daemon processes
- **Resource Monitoring**: Extracts thread counts, memory usage, CPU percentages
- **Database Integration**: Optional integration with Rocoto workflow databases
- **Ruby Infrastructure**: Built on the same foundation as other Rocoto utilities

## Troubleshooting

### No daemons found
- Verify Rocoto workflows are active
- Check that daemon processes are running with `ps aux | grep rocoto`
- Ensure proper permissions to view process information

### Permission errors
- Make sure you have read access to `/proc` filesystem
- Verify execute permissions on the `rocotometrics` script

### Database connection issues
- Check database file path and permissions
- Verify SQLite3 Ruby gem is available
- Use `-v 2` for detailed error messages

## Performance Impact

`rocotometrics` is designed to be lightweight:
- Uses standard system calls (`ps`, `/proc` filesystem)
- Minimal memory footprint
- No impact on monitored daemon processes
- Efficient data collection and display

## Future Enhancements

Potential improvements for future versions:
- Historical trending and graphs
- Alerting for resource thresholds
- Integration with external monitoring systems
- Performance baseline comparisons
- Export capabilities (JSON, CSV)

## See Also

- `rocotostat(1)` - Workflow status information
- `rocotorun(1)` - Run workflow cycles
- `ps(1)` - Process status
- `top(1)` - Display running processes
