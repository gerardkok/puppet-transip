require 'puppet/util/feature'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet.features.add(:transip_configured) do
  File.exist?(Transip::Client.config_file)
end
