require_relative "exports"
require_relative "functions"

require "yaml"
require "json"

default_inventory = {
  "config" => {
    "ssh" => YAML.load(File.open("#{File.dirname(__FILE__)}/config/ssh.yml")),
    "vm" => JSON.parse(JSON.dump(YAML.load(File.open("#{File.dirname(__FILE__)}/config/vm.yml"))), symbolize_names: true)
  },
  "roles" => {
    "ansible" => {
      "tasks" => { "ansibleinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/ansibleinit.yml")) }
    },
    "docker" => {
      "tasks" => { "dockerinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/dockerinit.yml")) }
    },
    "all" => {
      "tasks" => {
        "devinit" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/devinit.yml")),
        "sysinfo" => YAML.load(File.open("#{File.dirname(__FILE__)}/tasks/sysinfo.yml"))
      }
    }
  }
}

$inventory = default_inventory.deep_merge YAML.load($inventory)
$inventory["roles"]["all"]["cpus"] = ($host_cpu_count / 2).ceil
$inventory["roles"]["all"]["mem"]  = [[($host_memory_mb / 2.75 / 512 - 1).floor * 512, 1024].max, 3072].min
$inventory["$inventory"] ||= { PROJECT_NAME => { "hostname" => PROJECT_NAME } }

if File.exists?("#{PROJECT_PATH}/vagrant.yml")
  $inventory = $inventory.deep_merge YAML.load(File.open("#{PROJECT_PATH}/vagrant.yml"))
end

require_relative "vagrantfile"
