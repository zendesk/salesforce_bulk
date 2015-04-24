require 'minitest/autorun'
require 'shoulda'
require 'mocha/setup'
require 'webmock/test_unit'
require 'salesforce_bulk'

class Test::Unit::TestCase

  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  def api_url(client)
    "https://#{client.login_host}/services/async/#{client.version}/"
  end

  def bypass_authentication(client)
    client.instance_variable_set('@session_id', '123456789')
    client.instance_variable_set('@login_host', 'na9.salesforce.com')
    client.instance_variable_set('@instance_host', 'na9.salesforce.com')
  end

  def fixture_path(file)
    File.expand_path("../fixtures/#{file}", __FILE__)
  end

  def fixture(file)
    File.new(fixture_path(file)).read
  end

end
