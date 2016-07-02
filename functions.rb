class ::Hash
  # http://stackoverflow.com/a/30225093/650329
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    self.merge(second.to_h, &merger)
  end
end

def merge_config(config, override)
  override.each do |k, v|
    if k[0] == "@"
      v.each do |params| config.send(k[1..-1], *params) end
    elsif v.is_a? Hash
      merge_config config.send(k), v
    else
      config.send "#{k}=", v
    end
  end
end

def filter_provider_os(key, host, provider, os)
  return (host[key] || {}).select { |k, v| not v["disabled"] and (v["providers"]||[provider]).include?(provider) and (v["hosts"]||[os]).include?(os) }
end

def sync_folders(override, host, provider, os)
  filter_provider_os("mount", host, provider, os).each do |n, folder|
    params = { :mount_options => [] }
    params[:mount_options] += [ "ro" ] if folder["readonly"]
    # default to nfs on supported platforms
    if provider == "virtualbox" or (provider == "lxc" and folder["readonly"])
      folder["type"] = "nfs" if folder["type"].nil? and os != "windows"
      params[:type] = folder["type"]
      params[:mount_options] += [ "dmode=775", "fmode=664" ] if os == "windows"
      params[:mount_options] += [ "vers=3", "udp", "actimeo=1", "rsize=65536", "wsize=65536", "noatime", "nolock", "fsc" ] if params[:type] == "nfs"
    end
    override.vm.synced_folder folder["src"], folder["dst"], params
  end
end

def provisioners(override, host, provider, os)
  provisioners = filter_provider_os("tasks", host, provider, os)
  provisioners = provisioners.sort_by { |k, v| v["priority"] || 20 }
  provisioners.each do |n, p|
    override.vm.provision n, type: "shell",
        privileged: (p["privileged"].nil? ? true : p["privileged"]),
        run: (p["run"] || "once") do |s|
      s.inline = p["inline"]
    end
  end
end
