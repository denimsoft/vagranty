# detect the host operating system and resources
if RbConfig::CONFIG["host_os"] =~ /linux/
  $host_cpu_count = `nproc`.to_i
  $host_memory_mb = `grep "MemTotal" /proc/meminfo | sed -e "s/MemTotal://" -e "s/ kB//"`.to_i / 1024
  $os = "linux"
elsif RbConfig::CONFIG["host_os"] =~ /darwin/
  $host_cpu_count = `sysctl -n hw.ncpu`.to_i
  $host_memory_mb = `sysctl -n hw.memsize`.to_i / 1024 / 1024
  $os = "darwin"
else
  $host_cpu_count = `wmic cpu get NumberOfCores`.split("\n")[2].to_i
  $host_memory_mb = `wmic OS get TotalVisibleMemorySize`.split("\n")[2].to_i / 1024
  $os = "windows"
end
