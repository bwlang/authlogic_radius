require 'authlogic'

module AuthlogicRadius
  module ActsAsAuthentic
    def self.included(klass)
      klass.class_eval do
        extend Config
        add_acts_as_authentic_module(Methods, :prepend)
      end
    end
    
    module Config
      # Whether or not to validate the radius_login field. If set to false ALL radius validation will need to be
      # handled by you.
      #
      # * <tt>Default:</tt> true
      # * <tt>Accepts:</tt> Boolean
      def validate_radius_login(value = nil)
        rw_config(:validate_radius_login, value, true)
      end
      alias_method :validate_radius_login=, :validate_radius_login
    end
    
    module Methods
      def self.included(klass)
        klass.class_eval do
          attr_accessor :radius_password
          
          if validate_radius_login
            validates_uniqueness_of :radius_login, :scope => validations_scope, :if => :using_radius?
          end
          validates_length_of_password_field_options validates_length_of_password_field_options.merge(:unless => :using_radius?)
          validates_confirmation_of_password_field_options validates_confirmation_of_password_field_options.merge(:unless => :using_radius?)
          validates_length_of_password_confirmation_field_options validates_length_of_password_confirmation_field_options.merge(:unless => :using_radius?)
          validates_length_of_login_field_options validates_length_of_login_field_options.merge(:unless => :using_radius?)
          validates_uniqueness_of_login_field_options validates_uniqueness_of_login_field_options.merge(:unless => :using_radius?)
          validates_format_of_login_field_options validates_format_of_login_field_options.merge(:unless => :using_radius?)

        end
      end

      private

      def using_radius?
        respond_to?(:radius_login) && respond_to?(:radius_password) &&
          (!radius_login.blank? || !radius_password.blank?)
      end
      
    end
  end
end