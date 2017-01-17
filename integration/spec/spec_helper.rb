require 'rspec/cog'

RSpec.configure do |config|
  config.include Cog::RSpec::Integration, :integration
end
