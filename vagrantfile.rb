Vagrant.configure(2) do |config|
  # merge vagrant config with $inventory
  merge_config config, $inventory["config"]

  $inventory["hosts"].each do |host_id, host|
    roles = {}
    (["all"] + (host["roles"] || [])).uniq.each do |group|
      roles = roles.deep_merge $inventory["roles"][group]
    end
    host = roles.deep_merge host
    host.delete "roles"

    host["hostname"] ||= host_id
    host["tasks"] = $inventory["tasks"].keep_if { |k, v| host["tasks"].key? k }.deep_merge host["tasks"] if not host["tasks"].nil?

    config.vm.define host["hostname"] do |box|
      # set the hostname
      box.vm.hostname = host["hostname"]

      # configure port forwarding and default auto_correct to true
      (host["forward"] || []).select { |v| not v["disabled"] }.each do |n, port|
        box.vm.network :forwarded_port,
            host: port["host"],
            guest: port["guest"],
            auto_correct: port["auto_correct"].nil? ? true : port["auto_correct"]
      end

      # virtualbox provider
      box.vm.provider :virtualbox do |vbox, override|
        override.vm.box = host["box"] || "geerlingguy/ubuntu1604"
        vbox.customize ["modifyvm", :id, "--memory", host["mem"]]
        vbox.customize ["modifyvm", :id, "--cpus", host["cpus"]]
        vbox.customize ["modifyvm", :id, "--name", host["hostname"]]

        sync_folders override, host, "virtualbox", $os
        provisioners override, host, "virtualbox", $os

        (host["interfaces"].nil? ? [ "dhcp" ] : host["interfaces"]).each do |ip|
          params = ip == "dhcp" ? { :type => "dhcp" } : { :ip => ip }
          override.vm.network :private_network, params
        end

        if Vagrant.has_plugin?("vagrant-bindfs")
          (host["mount"] || []).select { |folder| not folder["disabled"] }.each do |n, folder|
            params = {
              :owner => host["owner"] || folder["owner"] || 900,
              :group => host["group"] || folder["group"] || 900
            }
            params[:perms] = "u=rwX:go=rX:go-w" if $os == "windows"
            override.bindfs.bind_folder folder["dst"], folder["dst"], params
          end
        else
          $stderr.puts "WARNING: plugin not found: vagrant-bindfs\n"
        end
      end

      # lxc provider
      box.vm.provider :lxc do |lxc, override|
        override.vm.box = host["box"] || "developerinlondon/ubuntu_lxc_xenial_x64"
        lxc.customize "cgroup.memory.limit_in_bytes", "#{host["mem"]}M"
        lxc.customize "mount.auto", "cgroup"
        lxc.customize "aa_profile", "unconfined"
        lxc.customize "cgroup.devices.allow", "a"

        sync_folders override, host, "lxc", $os
        provisioners override, host, "lxc", $os

        (host["interfaces"] || []).each do |ip|
          if ip =~ /^10.0.3./
            if not host["lxc_ipv4"]
              lxc.customize "network.ipv4", ip
              host["lxc_ipv4"] = true
            end
          elsif ip != "dhcp"
            override.vm.network :private_network, ip: ip, lxc__bridge_name: host["bridge"] || "vlxcbr1"
          end
        end
      end
    end
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope ||= :machine
  end
end
