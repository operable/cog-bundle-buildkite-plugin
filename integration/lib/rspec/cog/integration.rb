require 'rspec/core'
require 'securerandom'
require 'net/http'
require 'json'
require 'pp'

module Cog
  module API

    def self.token(server_address, username, password)
      uri = URI("#{server_address}/v1/token")
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req.body = {username: username, password: password}.to_json

      Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.request(req)
        case resp
        when Net::HTTPSuccess
          JSON.parse(resp.body)["token"]["value"]
        else
          self.report_failure("Could not get token", resp)
        end
      end
    end

    def self.trigger(server_address, token, params)
      uri = URI("#{server_address}/v1/triggers")
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req["Authorization"] = "token #{token}"
      req.body = {trigger: params}.to_json

      Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.request(req)
        case resp
        when Net::HTTPSuccess
          JSON.parse(resp.body)["trigger"]
        else
          self.report_failure("Could not create trigger", resp)
        end
      end
    end

    def self.delete_trigger(server_address, token, name)
      uri = URI("#{server_address}/v1/triggers/#{name}")
      req = Net::HTTP::Delete.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req["Authorization"] = "token #{token}"

      Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.request(req)
        case resp
        when Net::HTTPSuccess
          resp
        else
          # Don't throw an exception if something fails here; we
          # create unique trigger names, and run in a disposable
          # container; cleaning up triggers isn't even strictly
          # necessary.
          STDERR.puts("Could not delete trigger: #{uri.inspect}")
        end
      end
    end

    def self.execute_trigger(invocation_url, body: nil)
      uri = URI(invocation_url)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      if body
        req.body = body.to_json
      end

      Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.request(req)
        case resp
        when Net::HTTPSuccess
          JSON.parse(resp.body)['pipeline_output']
        else
          self.report_failure("Could not execute trigger #{invocation_url}",
                              resp)
        end
      end
    end

    def self.report_failure(message, resp)
      STDERR.puts(message)
      STDERR.puts("Request Body: #{body.to_json.inspect}")
      STDERR.puts("Response Code: #{resp.code}")
      STDERR.puts("Response Message: #{resp.message}")
      STDERR.puts("Response Body: #{resp.body.inspect}")
      raise message
    end

  end
end


module Cog
  module RSpec
    module Integration
      extend ::RSpec::SharedContext

      let(:server_address) { ENV["COG_INTEGRATION_SERVER"] || raise("Must supply a server address to run") }

      let(:username) { ENV["COG_INTEGRATION_USERNAME"] || raise("Must supply cog username") }

      let(:password) { ENV["COG_INTEGRATION_PASSWORD"] || raise("Must supply cog password") }

      let(:trigger_name) { "test-pipeline-#{SecureRandom.uuid}" }

      let(:token) { Cog::API.token(server_address, username, password) }

      def trigger(pipeline)
        Cog::API.trigger(server_address,
                         token,
                         {pipeline: pipeline,
                          name: trigger_name,
                          as_user: username})
      end

      def execute(pipeline, on_input: nil)
        final_pipeline = if on_input
                           "operable:seed '" + on_input.to_json + "' | #{pipeline}"
                         else
                           pipeline
                         end

        trigger = trigger(final_pipeline)
        begin
          return Cog::API.execute_trigger(trigger["invocation_url"])
        ensure
          Cog::API.delete_trigger(server_address, token, trigger["id"])
        end
      end
    end

  end
end
