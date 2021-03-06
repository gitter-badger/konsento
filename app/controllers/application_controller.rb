require 'application_responder'

class ApplicationController < ActionController::Base
  include Clearance::Controller
  include NotificationsHelper

  self.responder = ApplicationResponder
  respond_to :html

  before_action :set_locale
  before_action :offer_login
  before_action :set_js_data
  before_action :add_root_breadcrumb
  before_action :current_model

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def recursive_location_path(location)
    locations = location.parents
    locations << location
    url_params = []
    subdomain = nil

    subdomain = current_model.slug if current_model.is_a?(Team)

    locations.each do |g|
      next if g.slug == 'global' # Global location doesn't show up in the url

      # Level 1 locations go into the subdomain, not params
      if current_model.is_a?(Location) && Location.level_1.exists?(g.id)
        subdomain ||= g.slug
        next
      end

      url_params << g.slug # The rest are url params
    end

    recursive_locations_url(url_params, subdomain: subdomain)
  end

  def current_model
    @current_model ||= if request.subdomain.present?
      subdomain = request.subdomain
      Location.level_1.find_by(slug: subdomain) ||
      Team.accessible_for(current_user).find_by(slug: subdomain) ||
      redirect_to(root_url(subdomain: nil))
    else
      Location.friendly.find('global')
    end
  end

  def add_recursive_location_breadcrumbs(location)
    location.parents.each do |parent|
      add_breadcrumb parent.title, recursive_location_path(parent)
    end

    add_breadcrumb location.title, recursive_location_path(location)
  end

  helper_method :recursive_location_path, :current_model

  private

  def add_root_breadcrumb
    add_breadcrumb t('home'), root_url(subdomain: nil)
  end

  def set_js_data
    gon.push(
      root_url: root_url,
      controller: params[:controller].classify,
      action: params[:action].classify,
      params: params
    )
  end


  def set_locale
    if language_change_necessary?
      I18n.locale = the_new_locale
      set_locale_cookie(I18n.locale)
    else
      use_locale_from_cookie
    end
  end

  def language_change_necessary?
    cookies.signed[:locale].nil? || params[:locale]
  end

  def the_new_locale
    new_locale = (params[:locale] || extract_locale_from_accept_language_header)
    I18n.available_locales.map(&:to_s).include?(new_locale) ? new_locale : I18n.default_locale.to_s
  end

  def set_locale_cookie(locale)
    cookies.permanent.signed[:locale] = {
      value: locale.to_s,
      domain: ".#{request.domain}"
    }
  end

  def use_locale_from_cookie
    I18n.locale = cookies.signed[:locale]
  end

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE'].presence.to_s.scan(
      /^[a-z]{2}\-[A-Z]{2}|^[a-z]{2}/
    ).first
  end

  def offer_login
    if request.path != sign_in_path &&
       request.path != sign_up_path &&
       request.request_method == 'GET' &&
       !signed_in? &&
       !ignore_offer_login?
      redirect_to sign_in_path(offer: true, referer: request.original_url)
    end
  end

  def ignore_offer_login?
    if params[:offer_login]
      cookies[:offer_login] = {
        value: params[:offer_login],
        domain: ".#{request.domain}"
      }
    end

    cookies[:offer_login].to_s == 'false'
  end
end
