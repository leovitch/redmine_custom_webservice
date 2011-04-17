require 'test_helper'

class CustomWebserviceTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end

class CustomWebserviceRoutingTest < Test::Unit::TestCase

  def setup
    ActionController::Routing::Routes.draw do |map|
      map.custom_webservice
    end
  end

  def test_webservice_route
    assert_recognition :get, "/custom_webservice/simpletest.xml", :controller => "custom_webservice_controller", :action => "simpletest", :format => "xml"
  end

  private
    # Cribbed from http://izumi.plan99.net/manuals/creating_plugins-8f53e4d6.html...
    # but this test still won't run on my machine due to gem madness.
    def assert_recognition(method, path, options)
      result = ActionController::Routing::Routes.recognize_path(path, :method => method)
      assert_equal options, result
    end
end

