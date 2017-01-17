require 'spec_helper'
require 'yaml'

manifest = YAML.load(File.read(ENV['INTEGRATION_MANIFEST']))

manifest.each do |command_suite|
  command, test_cases = command_suite

  describe "#{command}", :integration do
    test_cases.each do |tc|
      it tc['desc'] do
        result = execute(tc['pipeline'],
                         on_input: tc['input'])
        expect(result).to eq(tc['output'])
      end
    end
  end
end
