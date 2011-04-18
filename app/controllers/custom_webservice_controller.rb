

class CustomWebserviceController < ApplicationController
  # Must use global auth to avoid requiring a separate permission for every action
  before_filter :authorize_global, :except => [ :simple, :echo, :auth_echo ]
  
  # Generally you should only give this permission to a special user established
  # for this purpose only
  before_filter :authorize_custom_webservices

  # Remember to add all your authenticated actions to this list
  # (that's all of them, right?).
  # Unfortunately accept_key_auth doesn't have an :except parameter, 
  # so they must all be listed here rather than just before each
  # action.
  accept_key_auth :auth_echo, :find_issues_by_custom_field, :update_issue_status
  
  # Make sure to restrict your actions to appropriate HTML verbs.
  verify :method => :get,
         :only => [ :simple, :echo, :auth_echo, :find_issues_by_custom_field, ],
         :render => { :nothing => true, :status => :method_not_allowed }
  verify :method => :post,
         :only => [ :update_issue_status, ],
         :render => { :nothing => true, :status => :method_not_allowed }

  # And finally, our common param-fetching before_filters:
  before_filter :find_project_by_identifier, :only => [ :find_issues_by_custom_field, :update_issue_status, ]
  before_filter :find_tracker_by_name, :only => :update_issue_status
  before_filter :find_status_by_name, :only => :update_issue_status
  
  # Just a query that returns a constant string.
  # You should be able to test this from the shell with a command like
  # the following (assuming you're testing via mongrel):
  # % curl http://0.0.0.0:3000/custom_webservice/simple.json
  # Remember to delete this method before deploying, it is not authenticated.
  def simple
    respond_to do |format|
      format.xml  { render :xml => { :response => "Squawk!" } }
      format.json  { render :json => { :response => "Squawk!" } }
    end
  end
 
  # Query which will echo back its params.  Can be handy for debugging.
  # You should be able to test this from the shell with a command like
  # the following (assuming you're testing via mongrel):
  # % curl http://0.0.0.0:3000/custom_webservice/echo.json --get --data my_argument=my_value
  # Remember to delete this method before deploying, it is not authenticated.
  def echo
    respond_to do |format|
      format.json { render :json => params }
      format.xml  { render :xml => params }
    end
  end
  
  # Query which will echo its params, but using accept_key_auth.
  # You should be able to test this from the shell with a command like
  # the following (assuming you're testing via mongrel):
  # % curl http://0.0.0.0:3000/custom_webservice/auth_echo.xml --get \
  #    --data key=YOURAPIKEYHERE \
  #    --data my_argument=my_value
  def auth_echo
    respond_to do |format|
      format.json { render :json => params }
      format.xml  { render :xml => params }
    end
  end

  # Finally, a real example of why you might want to do this:
  # a simple web service that finds an issue via a query on an
  # (single) arbitrary custom field.  The HTTP GET request must have
  # parameters custom_field_name and custom_field_value,
  # and project_identifier.
  # You should be able to test this from the shell with a command like
  # the following (assuming you're testing via mongrel):
  # curl http://0.0:3000/custom_webservice/find_issues_by_custom_field.xml --get \
  #    --data key=YOURAPIKEYHERE \
  #    --data custom_field_name=External%20Id \
  #    --data custom_field_value=T58 \
  #    --data project_identifier\=test11
  def find_issues_by_custom_field
    # Conveniently, custom field values are all strings so no type conversion needed
    issues = Issue.all :joins => { :custom_values => [ :custom_field, ], },
                       :conditions => { :project_id => @project.id,
                                        :custom_values => { :value => params[:custom_field_value],
                                                            :custom_fields => { :name => params[:custom_field_name] } } }
    respond_to do |format|
      format.json { render :json => issues }
      format.xml { render :xml => issues }
    end
  end
  
  # Here's a POST-style example:  this action finds an issue
  # based on project, tracker, and subject.  If exactly
  # one issue is found, it updates the status to the given
  # status.  Parameters must include:
  # - project_identifier
  # - tracker_name
  # - subject
  # - status_name
  #  
  # You should be able to test this from the shell with a command like
  # the following (assuming you're testing via mongrel):
  # curl http://0.0:3000/custom_webservice/update_issue_status.json \
  #    --data key=YOURAPIKEYHERE \
  #    --data project_identifier=test11 \
  #    --data tracker_name=Bug \
  #    --data subject=YOURSUBJECTHERE \
  #    --data status_name=Closed
  def update_issue_status
    issues = Issue.all :conditions => { :project_id => @project.id,
                                        :tracker_id => @tracker.id,
                                        :subject => params[:subject] }
    if issues.size > 1
      @project = nil
      @tracker = nil
      @status = nil
      render_error({:message => :error_cws_ambiguous_query, :status => 400}) 
    elsif issues.size == 0
      render_404
    else
      issue = issues[0]
      if !issue.new_statuses_allowed_to(User.current).include? @status
        render_403
      else
        if issue.status.id != @status.id
          issue.init_journal(User.current)
          issue.status = @status
          if issue.save
            if Setting.notified_events.include?('issue_updated')
              Mailer.deliver_issue_edit(issue.current_journal)
            end
            respond_to do |format|
              format.json { render :json => issue }
              format.xml { render :xml => issue }
            end
          else
            render_403
          end
        else
          # Return unchanged issue
          respond_to do |format|
            format.json { render :json => issue }
            format.xml { render :xml => issue }
          end
        end
      end
    end
  end
  
protected
  def authorize_custom_webservices
    User.current.allowed_to?({:controller => self, :action => :access_custom_web_services}, nil, :global => true)
  end

  # Overridden from ActiveController to allow API requests without triggering the form forgery
  # code.  Note that this means you should only run custom_webservices on the LAN
  # or via https: anyone who snoops your packets can forge requests.
  def verify_authenticity_token
    true
  end
  
  def find_project_by_identifier
    @project = Project.find_by_identifier(params[:project_identifier])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_tracker_by_name
    @tracker = Tracker.find_by_name(params[:tracker_name])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_status_by_name
    @status = IssueStatus.find_by_name(params[:status_name])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
end

