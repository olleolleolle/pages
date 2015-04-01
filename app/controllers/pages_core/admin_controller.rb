# encoding: utf-8

# All admin controllers inherit Admin::AdminController, which provides layout,
# authorization and other common code for the Admin set of controllers.
module PagesCore
  class AdminController < ApplicationController
    before_action :set_i18n_locale
    before_action :require_authentication
    before_action :restore_persistent_params
    after_action :save_persistent_params

    layout "admin"

    def redirect
      if Page.news_pages.any?
        redirect_to news_admin_pages_url(@locale)
      else
        redirect_to admin_pages_url(@locale)
      end
    end

    protected

    def set_i18n_locale
      I18n.locale = :en
    end

    # Verifies the login. Redirects to users/new if the users table is empty.
    # If not, renders the login screen.
    def require_authentication
      return if logged_in?
      if User.count < 1
        redirect_to(new_admin_user_url) && return
      else
        redirect_to(login_admin_users_url) && return
      end
    end

    # Loads persistent params from user model and merges with session.
    def restore_persistent_params
      return unless current_user && current_user.persistent_data?
      session[:persistent_params] ||= {}
      session[:persistent_params] = current_user.persistent_data.merge(
        session[:persistent_params]
      )
    end

    # Saves persistent params from session to User model if applicable.
    def save_persistent_params
      return unless current_user && session[:persistent_params]
      current_user.persistent_data = session[:persistent_params]
      current_user.save
    end

    def secure_compare(a, b)
      return false unless a && b
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end

    # --- HELPERS ---

    # Get name of class with in lowercase, with underscores.
    def self.underscore
      ActiveSupport::Inflector.underscore(to_s).split(/\//).last
    end

    # Add a stylesheet
    def add_stylesheet(css_file)
      @admin_stylesheets ||= []
      @admin_stylesheets << "admin/#{css_file}"
    end

    def persistent_params(namespace)
      session[:persistent_params] ||= {}
      session[:persistent_params][namespace] ||= {}
      session[:persistent_params][namespace]
    end

    def coerce_persistent_param(v)
      case v
      when "true"
        true
      when "false"
        false
      else
        v
      end
    end

    # Get a persistent param
    def persistent_param(key, default = nil, options = {})
      namespace = options[:namespace] || self.class.to_s

      value = coerce_persistent_param(params.key?(key) ? params[key] : default)

      if !value.nil? || options[:preserve_nil]
        persistent_params(namespace)[key] = value
      end

      value
    end
  end
end
