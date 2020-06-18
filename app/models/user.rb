# frozen_string_literal: true

# User model (powered by Devise)
class User < ApplicationRecord
  include Email

  # Include default and most extra devise modules
  # (Only :omniauthable not currently used)
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable, :trackable
  devise :pwned_password unless Rails.env.test?

  # Allowed characters for usernames: a-z A-Z 0-9 . _ -
  USERNAME_REGEX = %r{[-_.a-zA-Z0-9]+}.freeze
  public_constant :USERNAME_REGEX
  ANCHORED_USERNAME_REGEX = %r{\A#{USERNAME_REGEX}\z}.freeze
  private_constant :ANCHORED_USERNAME_REGEX

  validates :username, presence:   true
  validates :username, uniqueness: true, case_sensitive: false
  validates :username, length:     { maximum: 50 }
  validates :username, format:     ANCHORED_USERNAME_REGEX

  # User profile pic (powered by ActiveStorage)
  has_one_attached :profile_pic

  # Authorisation (powered by Pundit)
  has_many :user_capabilities, dependent: :destroy
  has_many :capabilities, through: :user_capabilities, inverse_of: :users

  # User's custom site settings
  has_many :settings, class_name: 'SettingValue', inverse_of: :user,
                      dependent: :destroy

  # Web stats (powered by Ahoy)
  has_many :visits, class_name: 'Ahoy::Visit', dependent: :nullify
  # Email stats (also powered by Ahoy)
  has_many :messages, class_name: 'Ahoy::Message', dependent: :nullify

  # End-user content: destroy it along with their account
  has_many :comments, dependent: :destroy
  has_many :subscriptions, as: :subscriber, dependent: :destroy
  has_many :lists, through: :subscriptions

  # Admin content: throw an error if it hasn't been removed or reassigned
  has_many :blogs,      dependent: :restrict_with_error
  has_many :blog_posts, dependent: :restrict_with_error
  has_many :news_posts, dependent: :restrict_with_error

  # Configure default count-per-page for pagination
  paginates_per 20

  # Virtual attribute to allow authenticating by either username or email
  attr_writer :login

  def login
    @login || username || email
  end

  # Instance methods

  def admin?
    general = CapabilityCategory.find_by( name: 'general' )
    capabilities.exists? name: 'view_admin_area', category: general
  end

  def not_admin?
    !admin?
  end

  def can?( capability_name, category_name = :general )
    return admin_can?( capability_name, category_name ) if @all_capabilities.present?

    cc = CapabilityCategory.find_by( name: category_name.to_s )
    return true if capabilities.exists? name: capability_name.to_s, category: cc

    Rails.logger.debug  'Capability check failed: ' \
                        "#{username} cannot #{capability_name} #{category_name}"
    false
  end

  def admin_can?( capability, category = :general )
    return false if all_capabilities.blank?

    return true if all_capabilities[ category.to_s ]&.include? capability.to_s

    false
  end

  def all_capabilities
    return @all_capabilities if @all_capabilities.present?

    @all_capabilites =
      capabilities.joins( :category )
                  .group( 'capability_categories.name' )
                  .pluck( 'capability_categories.name', 'array_agg(capabilities.name)' )
                  .to_h
  end

  def capabilities=( capability_set )
    old_capabilities = user_capabilities.pluck( :capability_id ).sort
    new_capabilities = capability_set.keys.map( &:to_i ).sort

    remove = old_capabilities - new_capabilities
    add    = new_capabilities - old_capabilities

    add.each do |capability_id|
      user_capabilities.create!( capability_id: capability_id )
    end

    user_capabilities.where( capability_id: remove ).delete_all
  end

  def grant_all_capabilities
    User.transaction do
      Capability.all.find_each do |capability|
        user_capabilities.find_or_create_by! capability: capability
      end
    end
    self
  end

  def display_name_or_username
    display_name.presence || username
  end

  # Queue email sends
  def send_devise_notification( notification, *args )
    devise_mailer.public_send( notification, self, *args ).deliver_later
  end

  def primary_admin_area
    return unless admin?

    # List of admin areas, approximately in order of 'most commonly used'
    # (used by /admin index method to redirect somewhere hopefully useful)
    areas = %i[ pages blogs blog news_posts users settings ]

    areas.each do |area|
      return area if can? :list, area
    end
  end

  # Class methods

  # Return all users that have the specified capability
  def self.that_can( capability, category )
    CapabilityCategory.find_by( name: category.to_s )
                      .capabilities
                      .find_by( name: capability.to_s )
                      .user_capabilities
                      .map( &:user )
  end

  # Check whether we have at least one admin who can create more admins
  def self.super_admins_exist?
    that_can( :add, :admin_users ).present?
  end

  # Override find method to search by username as well as email
  def self.find_first_by_auth_conditions( warden_conditions )
    conditions = warden_conditions.dup
    login = conditions.delete( :login )
    if login
      where_clause = 'lower( username ) = :value OR lower( email ) = :value'
      where( conditions ).find_by( [ where_clause, { value: login.downcase } ] )
    elsif conditions[ :username ].nil?
      find_by( conditions )
    else
      find_by( username: conditions[ :username ] )
    end
  end
end
