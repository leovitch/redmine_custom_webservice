# Include hook code here

require 'custom_webservice'

Redmine::Plugin.register :custom_webservice do
  name 'Custom Webservice Example'
  author 'Leo Hourvitz'
  description 'Simple Custom Webservice example for Redmine.'
  version '0.2'

  project_module :custom_webservice do
    permission :access_custom_web_services, :custom_webservice => :index
  end
end

