class Policy
  module DefaultPolicy
    def index
      false
    end

    def new?
      false
    end

    def create?
      new?
    end

    def show?
      false
    end

    def edit?
      false
    end

    def update?
      edit?
    end

    def destroy?
      edit?
    end
  end

  include DefaultPolicy

  attr_reader :user, :record

  def initialize(user, record = nil)
    @user = user
    @record = record
  end

  class << self
    def for(user, object)
      if object.is_a?(Class)
        "#{object}Policy".constantize.collection(user)
      else
        "#{object.class}Policy".constantize.member(user, object)
      end
    end

    def collection(user)
      new(user)
    end

    def member(user, record)
      new(user, record)
    end
  end
end
