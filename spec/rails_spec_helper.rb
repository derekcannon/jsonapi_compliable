# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.
require 'bundler/setup' unless defined?(Bundler)
require 'rails'
require 'action_controller'
require 'jsonapi_compliable/rails'

module BasicRailsApp
  module_function

  # Make a very basic app, without creating the whole directory structure.
  # Is faster and simpler than generating a Rails app in a temp directory
  def generate
    @app = Class.new(Rails::Application) do
      config.eager_load = false
      config.session_store :cookie_store, key: '_myapp_session'
      config.active_support.deprecation = :log
      config.root = File.dirname(__FILE__)
      config.log_level = :info
      # Set a fake logger to avoid creating the log directory automatically
      fake_logger = Logger.new(nil)
      config.logger = fake_logger
      Rails.application.routes.default_url_options = { host: 'example.com' }
      
      # fix railties 5.2.0 issue with secret_key_base
      # https://github.com/rails/rails/commit/7419a4f9 should take care of it 
      # in the future.
      if Rails::VERSION::STRING == '5.2.0' 
        def secret_key_base
          '3b7cd727ee24e8444053437c36cc66c4'
        end
      end
    end
    @app.respond_to?(:secrets) && @app.secrets.secret_key_base = '3b7cd727ee24e8444053437c36cc66c4'

    yield @app if block_given?
    @app.initialize!
  end
end

::Rails.application = BasicRailsApp.generate

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  include JsonapiCompliable::Rails

  jsonapi do
    use_adapter JsonapiCompliable::Adapters::ActiveRecord
  end

  prepend_before_action :fix_params!

  private

  # Honestly not sure why this is needed
  # Otherwise params is { params: actual_params }
  def fix_params!
    if Rails::VERSION::MAJOR == 4
      good_params = { action: action_name }.merge(params[:params] || {})
      self.params = ActionController::Parameters.new(good_params.with_indifferent_access)
    end
  end
end

require 'rspec/rails'

# https://github.com/rails/rails/issues/34790#issuecomment-450502805
if RUBY_VERSION>='2.6.0'
  if Rails.version < '5'
    class ActionController::TestResponse < ActionDispatch::TestResponse
      def recycle!
        # hack to avoid MonitorMixin double-initialize error:
        @mon_mutex_owner_object_id = nil
        @mon_mutex = nil
        initialize
      end
    end
  else
    puts "Monkeypatch for ActionController::TestResponse no longer needed"
  end
end
