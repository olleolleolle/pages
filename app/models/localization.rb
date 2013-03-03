# encoding: utf-8

class Localization < ActiveRecord::Base
  belongs_to :localizable, :polymorphic => true

  class << self

    def locales
      self.select('locale').uniq.map{ |l| l.locale }
    end

    def names
      self.select('name').uniq.map{ |l| l.name }
    end

  end

  def to_s
    self.value || ""
  end

  def empty?
    self.to_s.empty?
  end

  def translate(locale)
    localizable.localizations.where(:name => self.name, :locale => locale).first
  end

end
