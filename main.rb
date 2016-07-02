require_relative "exports"
require_relative "functions"

require "yaml"
require "json"

$inventory = YAML.load($inventory)
$inventory["roles"] ||= { "default" => { "tasks" => $inventory["tasks"] } }
$inventory["hosts"] ||= { PROJECT_NAME => { "roles" => $inventory["roles"].keys } }

default_inventory = {
  "config" => {
    "ssh" => YAML.load(File.open("#{File.dirname(__FILE__)}/config/ssh.yml")),
    "vm" => JSON.parse(JSON.dump(YAML.load(File.open("#{File.dirname(__FILE__)}/config/vm.yml"))), symbolize_names: true)
  },
  "tasks" => {
    "ansibleinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/ansibleinit.yml")),
    "dockerinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/dockerinit.yml")),
    "devinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/devinit.yml")),
    "sysinfo" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/sysinfo.yml"))
  },
  "roles" => {
    "all" => {
      "cpus" => ($host_cpu_count / 2).ceil,
      "mem" => [[($host_memory_mb / 2.75 / 512 - 1).floor * 512, 1024].max, 3072].min,
      "tasks" => {
        "devinit" => { },
        "sysinfo" => { }
      }
    }
  }
}

$inventory = default_inventory.deep_merge $inventory

if File.exists?("#{PROJECT_PATH}/vagrant.yml")
  $inventory = $inventory.deep_merge YAML.load(File.open("#{PROJECT_PATH}/vagrant.yml"))
end

$inventory["hosts"] = filter_provider_os "hosts", $inventory, nil, $os

require_relative "vagrantfile"
