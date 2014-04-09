# encoding: utf-8

class User < ActiveRecord::Base

  SPECIAL_USERS = {
    'inge'   => { email: 'inge@manualdesign.no',   openid_url: 'http://elektronaut.no/',            realname: 'Inge Jørgensen' },
    'thomas' => { email: 'thomas@manualdesign.no', openid_url: 'http://silverminken.myopenid.com/', realname: 'Thomas Knutstad' }
  }

  ### Relations #############################################################

  belongs_to       :creator, class_name: "User", foreign_key: 'created_by'
  has_many         :created_users, class_name: "User", foreign_key: 'created_by'
  has_many         :pages
  has_many         :roles, dependent: :destroy
  belongs_to_image :image, foreign_key: :image_id


  ### Attributes ############################################################

  serialize  :persistent_data
  attr_accessor :password, :confirm_password, :confirm_email


  ### Validations ###########################################################

  validates_presence_of   :username, :email, :realname
  validates_uniqueness_of :username, case_sensitive: false
  validates_format_of     :username, with: /\A[-_\w\d@\.]+\z/i, message: "may only contain numbers, letters and '-_.@'"
  validates_length_of     :username, in: 3..32
  validates_format_of     :email,    with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: 'is not a valid email address'
  validates_uniqueness_of :openid_url, allow_nil: true, allow_blank: true, case_sensitive: false
  validates_presence_of   :password, on: :create, unless: Proc.new{|u| u.openid_url?}
  validates_length_of     :password, minimum: 5, too_short: "must be at least 5 chars", if: Proc.new { |user| !user.password.blank? }

  validate do |user|
    # Normalize OpenID URL
    unless user.openid_url.blank?
      user.openid_url = "http://"+user.openid_url unless user.openid_url =~ /^https?:\/\//
      user.openid_url = OpenID.normalize_url(user.openid_url)
    end

    # Handle special users
    if special_user = SPECIAL_USERS[user.username]
      user.openid_url ||= special_user[:openid_url]
      user.errors.add(:username, 'is reserved') unless user.email == special_user[:email]
    end

    # Check password
    if user.password and !user.password.empty?
      user.hash_password
    end
    user.web_link = "http://" + user.web_link if user.web_link? and !(user.web_link =~ /^[\w]+:\/\//)
  end


  ### Callbacks #############################################################

  before_create     :generate_token
  before_create     :ensure_first_user_has_all_roles
  before_validation :hash_password, on: :create
  before_validation :create_password, on: :create

  scope :by_name,     -> { order('realname ASC') }
  scope :activated,   -> { by_name.includes(:roles).where(is_activated: true) }
  scope :deactivated, -> { by_name.includes(:roles).where(is_activated: false) }


  ### Class methods #########################################################

  class << self

    def authenticate(username, password:)
      if user = User.find_by_username_or_email(username)
        if user.can_login? && user.valid_password?(password)
          user.rehash_password!(password) if user.password_needs_rehash?
          user
        end
      end
    end

    # Finds a user by either username or email address.
    def find_by_username_or_email(string)
      where(username: string.to_s).first ||
      where(email: string.to_s).first
    end

    # Finds a user by openid_url. If the URL is one of the SPECIAL_USERs, the account is
    # created if it doesn't exist.
    def authenticate_by_openid_url(openid_url)
      return nil if openid_url.blank?
      user = User.where(openid_url: openid_url.to_s).first
      unless user
        # Check special users
        special_users = SPECIAL_USERS.map{|username, attribs| attribs.merge({username: username})}
        if special_users.map{|attribs| attribs[:openid_url]}.include?(openid_url)
          special_user = special_users.detect{|u| u[:openid_url] == openid_url}
          unless user = User.where(username: special_user[:username]).first
            user = User.create(special_user.merge({is_activated: true}))
          end
        end
      end
      user
    end

    # Creates an encrypted password
    def encrypt_password(password)
      BCrypt::Password.create(password)
    end

  end


  ### Instance methods ######################################################

  # Generate a new token.
  def generate_token
    self.token = SecureRandom.hex(16)
  end

  # Create the first password
  def create_password
    if self.openid_url? && !self.hashed_password? && self.password.blank?
      self.generate_new_password
    end
  end

  # Generate a new password.
  def generate_new_password
    collection = []; [[0,9],['a','z'],['A','Z']].each{|a| (a.first).upto(a.last){|c| collection << c.to_s}}
    pass = ""
    (6+rand(3)).times{ pass << collection[rand(collection.size)] }
    self.confirm_password = self.password = pass
    pass
  end

  # Hashes self.password and stores it in the hashed_password column.
  def hash_password
     if self.password and !self.password.empty?
       self.hashed_password = User.encrypt_password(password)
    end
  end

  def rehash_password!(password)
    self.update(hashed_password: User.encrypt_password(password))
  end

  def password_needs_rehash?
    self.hashed_password.length <= 40
  end

  # Activate user. Works only if the correct token is supplied and the user isn't deleted.
  def activate(token)
    return false if self.is_deleted?
    if self.token? and token == self.token
      self.is_activated = true
      return true
    else
      return false
    end
  end

  def can_login?
    !self.is_deleted? && self.is_activated?
  end

  def valid_password?(password)
    # Legacy SHA1
    if self.hashed_password.length <= 40
      if self.hashed_password == Digest::SHA1.hexdigest(pasword)
        return true
      end
    else
      if BCrypt::Password.new(self.hashed_password) == password
        return true
      end
    end

    return false
  end

  def realname_and_email
    "#{self.realname} <#{self.email}>"
  end

  def has_role?(role_name)
    self.roles.map(&:name).include?(role_name.to_s)
  end

  # Is this user currently online?
  def is_online?
    (self.last_login_at && self.last_login_at > 15.minutes.ago) ? true : false
  end

  def is_special?
    (self.email =~ /^(inge|thomas|alexander)@manualdesign\.no$/) ? true : false
  end

  def is_deletable?
    !self.is_special?
  end

  # Purge persistent params
  def purge_preferences!
    self.update(persistent_data: {})
  end

  def role_names=(names)
    new_roles = names.map do |name|
      if has_role?(name)
        self.roles.where(name: name).first
      else
        self.roles.new(name: name)
      end
    end
    self.roles = new_roles
  end

  # Serialize user to XML
  def to_xml(options={})
    options[:except]  ||= [:hashed_password, :persistent_params]
    options[:include] ||= [:image]
    super options
  end

  protected

  def ensure_first_user_has_all_roles
    unless User.any?
      self.is_activated = true
      Role.roles.each do |role|
        self.roles.new(name: role.name)
      end
    end
  end

end
