require "authlogic_radius/version"
require "authlogic_radius/acts_as_authentic"
require "authlogic_radius/session"

ActiveRecord::Base.send(:include, AuthlogicRadius::ActsAsAuthentic)
Authlogic::Session::Base.send(:include, AuthlogicRadius::Session)