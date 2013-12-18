require 'bundler'
require 'json'
require 'logger'
Bundler.require

module Karma
  LOGGER = ::Logger.new "karma.log"
  module Dashboard
  end
  class Hotspot

    def self.status
      Karma::Hotspot::Status.new
    end
  end
end

class Karma::Dashboard::Status
end

class Karma::Hotspot::Status

  STATUS_URL = 'https://hotspot.yourkarma.com/api/status.json'

  def initialize
    @results = nil
    @promise = Concurrent::Promise.new { update! }
  end

  def get
    @results ||= update!
  end

  def update!
    @results = retrieve
  end

  def retrieve
    begin
      response = ::RestClient.get STATUS_URL do |response, request, result, &block|
        case response.code
        when 200
          Karma::LOGGER.info "success"
          Karma::LOGGER.info response
          response
        else
          response.return!(request, result, &block)
        end
      end
      ::JSON.parse response.to_str
    rescue SocketError => e
      Karma::LOGGER.error e.to_s
      return {:error => e.message}
    end
  end
end
