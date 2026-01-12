# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20231024.0.0"
  
  config.vm.hostname = "posduif-dev"
  
  # Network configuration
  config.vm.network "forwarded_port", guest: 5432, host: 5432, id: "postgres"
  config.vm.network "forwarded_port", guest: 6379, host: 6379, id: "redis"
  config.vm.network "forwarded_port", guest: 8080, host: 8080, id: "sse"
  config.vm.network "forwarded_port", guest: 3000, host: 3000, id: "web"
  
  # Provider configuration
  config.vm.provider "virtualbox" do |vb|
    vb.name = "posduif-dev"
    vb.memory = "4096"
    vb.cpus = 2
  end
  
  # Provisioning
  config.vm.provision "shell", path: "scripts/setup.sh"
  
  # Synced folders
  config.vm.synced_folder ".", "/vagrant", disabled: false
end



