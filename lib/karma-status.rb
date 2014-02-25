require 'bundler'
require 'json'
require 'logger'
require 'deep_struct'
Bundler.require

module Karma
  LOGGER = ::Logger.new "karma.log"
  class Dashboard
    def self.status email, password
      Karma::Dashboard::Status.new email, password
    end
  end
  class Hotspot

    def self.status
      Karma::Hotspot::Status.new
    end
  end
end

class Karma::Dashboard::Status

  LOGIN_URL = 'https://yourkarma.com/login'
  DASHBOARD_URL = 'https://yourkarma.com/dashboard'

  def initialize email, password
    @results = nil
    @email = email
    @password = password
  end

  def get
    @results ||= update!
  end

  def update!
    @results = retrieve_dashboard @email, @password
  end

  
  def retrieve_dashboard email, password
    agent = Mechanize.new
    page = agent.get LOGIN_URL
    form = page.form
    form.email = email
    form.password = password
    page = agent.submit form
    page = agent.get DASHBOARD_URL

    @results = extract_status page
  end

  def extract_status page
    results = DeepStruct.new
    results.balance = page.search('#account-holder-balance span.human-balance').first.attr('title').split[0].gsub(',','').to_i
    results.referral_balance = page.search('div.referral-program-balance span.human-balance').first.attr('title').split[0].gsub(',','').to_i

    results
  end

end

class Karma::Hotspot::Status

  STATUS_URL = 'https://hotspot.yourkarma.com/api/status.json'

  def initialize
    @results = nil
    @promise = Concurrent::Promise.new { update! }
  end

  # Gets device status object
  def device
    Decorator.decorate get_raw
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


# Makes getting status items more object-friendly.
#
# Structure:
# {
# :name=>"IMW-C918W",
# :swversion=>"R4855",
# :hwversion=>"R06",
# :uptime=>"P0Y0M0DT0H25M21S",
# :batterypower=>100,
# :charging=>false,
# :waninterface=>{
#    :macaddress=>"001E31117CBE",
#    :ipaddress=>"75.95.16.222",
#    :bsid=>"00:00:02:21:25:22",
#    :rssi=>-50,
#    :cinr=>33,
#    :connectionduration=>"P0Y0M0DT0H24M17S"
# },
# :wifiinterface=>{
#   :ssid=>"Free Wi-Fi by Karma", 
#   :users=>1
# }
# }
class Karma::Hotspot::Status::Decorator < DeepStruct
  def self.decorate status_hash
    self.new status_hash["device"]
  end
end
