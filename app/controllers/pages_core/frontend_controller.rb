# encoding: utf-8

# Abstract controller for all frontend controllers.
class PagesCore::FrontendController < ApplicationController

  include ApplicationHelper

  before_action :set_i18n_locale

  # Loads @root_pages and @rss_feeds. To automatically load these in your own controllers,
  # add the following line to your controller definition:
  #
  #   before_action :load_root_pages
  #
  def load_root_pages
    @root_pages = Page.roots.localized(@locale).published
    @rss_feeds = Page.where(feed_enabled: true).localized(@locale).published
  end

  private

  def set_i18n_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

end
