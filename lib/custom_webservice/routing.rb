

module Redmine_Webservices #: nodoc
  module Routing #:nodoc
    module MapperExtensions
      def custom_webservice
        @set.add_route("/custom_webservice/simple.:format", {:controller => "custom_webservice", :action => "simple" })
        @set.add_route("/custom_webservice/:action.:format", {:controller => "custom_webservice" })
      end
    end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, Redmine_Webservices::Routing::MapperExtensions


