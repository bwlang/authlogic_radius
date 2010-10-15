require 'timeout'
require 'radiustar'

module AuthlogicRadius
  module Session
    
    def self.included(klass)
      klass.class_eval do
        extend Config
        include Methods
      end
    end
    
    module Config
      # The host of your RADIUS server.
      #
      # * <tt>Default:</tt> nil
      # * <tt>Accepts:</tt> String
      def radius_host(value = nil)
        rw_config(:radius_host, value)
      end
      alias_method :radius_host=, :radius_host
      
      # The port of your RADIUS server.
      #
      # * <tt>Default:</tt> 18121
      # * <tt>Accepts:</tt> Fixnum, integer
      def radius_port(value = nil)
        rw_config(:radius_port, value, 1812)
      end
      alias_method :radius_port=, :radius_port

      # The shared secret issued by your RADIUS server
      #
      # * <tt>Default:</tt> nil
      # * <tt>Accepts:</tt> String
      def radius_shared_secret(value = nil)
        rw_config(:radius_shared_secret, value)
      end
      alias_method :radius_shared_secret=, :radius_shared_secret


      # How long to wait for a response from the RADIUS server
      # * <tt>Default:</tt> 2 seconds
      # * <tt>Accepts:</tt> Fixnum, integer
      def radius_timeout(value = 2)
        rw_config(:radius_timeout, value)
      end
      alias_method :radius_timeout=, :radius_timeout

      # Which database field should be used to store the radius login
      # * <tt>Defaults:</tt> :radius_login
      # * <tt>Accepts:</tt> Symbol
      def radius_login_field(value=nil)
        rw_config(:radius_login_field, value, :radius_login)
      end
      alias_method :radius_login_field=, :radius_login_field

      # Set to indicate whether users should be created here upon successful authentication
      # * <tt>Defaults:</tt> true
      # * <tt>Accepts:</tt> Boolean
      def auto_register(value=nil)
        rw_config(:auto_register,value, true)
      end
      alias_method :auto_register=, :auto_register

      # The domain part added to the login to generate an email address
      # * <tt>Defaults:</tt> nil
      # * <tt>Accepts:</tt> String
      def auto_register_domain(value=nil)
        rw_config(:auto_register_domain, value)
      end
      alias_method :auto_register_domain=, :auto_register_domain
      
      # Defines a method to call when a user is auto registered.
      # This is intended to allow for custom user configuration (i.e. adding roles, etc).
      #
      # * <tt>Default:</tt> :configure_new_radius_user
      # * <tt>Accepts:</tt> Symbol
      def auto_register_method(value=nil)
        rw_config(:auto_register_method, value, :configure_new_radius_user)
      end
      alias_method :auto_register_method=, :auto_register_method

      # Once RADIUS authentication has succeeded we need to find the user in the database. By default this just calls the
      # find_by_radius_login method provided by ActiveRecord. If you have a more advanced set up and need to find users
      # differently specify your own method and define your logic in there.
      #
      # For example, if you allow users to store multiple radius logins with their account, you might do something like:
      #
      #   class User < ActiveRecord::Base
      #     def self.find_by_radius_login(login)
      #       first(:conditions => ["#{RadiusLogin.table_name}.login = ?", login], :join => :radius_logins)
      #     end
      #   end
      #
      # * <tt>Default:</tt> :find_by_radius_login
      # * <tt>Accepts:</tt> Symbol
      def find_by_radius_login_method(value = nil)
        rw_config(:find_by_radius_login_method, value, :find_by_radius_login)
      end
      alias_method :find_by_radius_login_method=, :find_by_radius_login_method
    end
    
    module Methods
      def self.included(klass)
        klass.class_eval do
          attr_accessor :radius_login
          attr_accessor :radius_password
          attr_accessor :radius_domain
          validate :validate_by_radius, :if => :authenticating_with_radius?
        end
      end
      
      # Hooks into credentials to print out meaningful credentials for RADIUS authentication.
      def credentials
        if authenticating_with_radius?
          details = {}
          details[:radius_login] = send(radius_login_field)
          details[:radius_host] = radius_host
          details[:radius_password] = "<protected>"
          details[:radius_shared_secret] = "<protected>"
          details
        else
          super
        end
      end
      
      # Hooks into credentials so that you can pass an :radius_login and :radius_password key.
      def credentials=(value)
        super
        values = value.is_a?(Array) ? value : [value]
        hash = values.first.is_a?(Hash) ? values.first.with_indifferent_access : nil
        if !hash.nil?
          if hash.key?(:radius_login)
            (login, domain) = hash[:radius_login].split('@')
            self.radius_domain = domain || auto_register_domain
            self.radius_login = login
          end
          self.radius_password = hash[:radius_password] if hash.key?(:radius_password)
        end
      end
      
      private
        def authenticating_with_radius?
          return radius_host && radius_shared_secret && radius_login
        end

        def auto_register?
          self.class.auto_register
        end

        def auto_register_domain
          self.class.auto_register_domain
        end
        
        def validate_by_radius
          errors.add(:radius_login, I18n.t('error_messages.radius_login_blank', :default => "can not be blank")) if radius_login.blank?
          errors.add(:radius_password, I18n.t('error_messages.radius_password_blank', :default => "can not be blank")) if radius_password.blank?
          return if errors.count > 0

          begin
            req = Radiustar::Request.new("#{radius_host}:#{radius_port}")
          rescue => e
            errors.add_to_base(I18n.t('error_messsages.cannot_resolve_radius_server', :default => "Unable to find a network path to RADIUS server at #{radius_host}:#{radius_port}"))
            return
          end

          begin
            
            Timeout.timeout(radius_timeout) do
              if req.authenticate(radius_login,radius_password,radius_shared_secret)
                #authentication succeeded, find or create the user
                self.attempted_record = search_for_record(find_by_radius_login_method, radius_login)

                if attempted_record.blank? && auto_register?
                  self.attempted_record = klass.new(
                    :radius_login => radius_login,
                    :email => "#{radius_login}@#{radius_domain}",
                    :remember_me => controller.params[:remember_me] == "true"
                  )
                  auto_register_method.to_proc.call(self.attempted_record)
                  if self.attempted_record.save
                    Rails.logger.info 'New user created'
                  else
                    Rails.logger.debug "#{self.attempted_record.errors.full_messages}"
                    errors.add_to_base(I18n.t('error_messages.failed_to_create_local_user', :default => "Failed to create a local user record."))
                  end
                else
                  errors.add(:radius_login, I18n.t('error_messages.radius_login_not_found', :default => "does not exist")) if attempted_record.blank?
                end
              else
                errors.add_to_base(I18n.t('error_messages.authentication_failed', :default => "Authentication failed"))
              end
            end
          rescue Timeout::Error
            errors.add_to_base(I18n.t('error_messages.radius_server_unavailable', :default => "No response from RADIUS server at #{radius_host}:#{radius_port}"))
          rescue => e
            errors.add_to_base(e.to_s)
          end
        end
        
        def radius_host
          self.class.radius_host
        end
        
        def radius_port
          self.class.radius_port
        end
        
        def radius_shared_secret
          self.class.radius_shared_secret
        end

        def auto_register
          self.class.auto_register
        end

        def auto_register_domain
          self.class.auto_register_domain
        end
        
        def auto_register_method
          self.class.auto_register_method
        end

        def radius_timeout
          self.class.radius_timeout
        end

        def find_by_radius_login_method
          self.class.find_by_radius_login_method
        end

    end
  end
end