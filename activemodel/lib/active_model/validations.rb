require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/keys'
require 'active_model/errors'

module ActiveModel
  
  # Provides a full validation framework to your objects.
  # 
  # A minimal implementation could be:
  # 
  #   class Person
  #     include ActiveModel::Validations
  # 
  #     attr_accessor :first_name, :last_name
  #
  #     validates_each :first_name, :last_name do |record, attr, value|
  #       record.errors.add attr, 'starts with z.' if value.to_s[0] == ?z
  #     end
  #   end
  # 
  # Which provides you with the full standard validation stack that you
  # know from ActiveRecord.
  # 
  #   person = Person.new
  #   person.valid?
  #   #=> true
  #   person.invalid?
  #   #=> false
  #   person.first_name = 'zoolander'
  #   person.valid?         
  #   #=> false
  #   person.invalid?
  #   #=> true
  #   person.errors
  #   #=> #<OrderedHash {:first_name=>["starts with z."]}>
  # 
  # Note that ActiveModel::Validations automatically adds an +errors+ method
  # to your instances initialized with a new ActiveModel::Errors object, so
  # there is no need for you to add this manually.
  # 
  module Validations
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    included do
      extend ActiveModel::Translation
      define_callbacks :validate, :scope => :name

      class_attribute :_validators
      self._validators = Hash.new { |h,k| h[k] = [] }
    end

    module ClassMethods
      # Validates each attribute against a block.
      #
      #   class Person
      #     include ActiveModel::Validations
      # 
      #     attr_accessor :first_name, :last_name
      #
      #     validates_each :first_name, :last_name do |record, attr, value|
      #       record.errors.add attr, 'starts with z.' if value.to_s[0] == ?z
      #     end
      #   end
      #
      # Options:
      # * <tt>:on</tt> - Specifies when this validation is active (default is <tt>:save</tt>,
      #   other options <tt>:create</tt>, <tt>:update</tt>).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+.
      # * <tt>:allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or
      #   <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or
      #   <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_each(*attr_names, &block)
        options = attr_names.extract_options!.symbolize_keys
        validates_with BlockValidator, options.merge(:attributes => attr_names.flatten), &block
      end

      # Adds a validation method or block to the class. This is useful when
      # overriding the +validate+ instance method becomes too unwieldly and
      # you're looking for more descriptive declaration of your validations.
      #
      # This can be done with a symbol pointing to a method:
      #
      #   class Comment
      #     include ActiveModel::Validations
      # 
      #     validate :must_be_friends
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Or with a block which is passed the current record to be validated:
      #
      #   class Comment
      #     include ActiveModel::Validations
      #
      #     validate do |comment|
      #       comment.must_be_friends
      #     end
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # This usage applies to +validate_on_create+ and +validate_on_update as well+.
      def validate(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options.key?(:on)
          options[:if] = Array(options[:if])
          options[:if] << "@_on_validate == :#{options[:on]}"
        end
        set_callback(:validate, *args, &block)
      end

      # List all validators that being used to validate the model using +validates_with+
      # method.
      def validators
        _validators.values.flatten.uniq
      end

      # List all validators that being used to validate a specific attribute.
      def validators_on(attribute)
        _validators[attribute.to_sym]
      end

    private

      def _merge_attributes(attr_names)
        options = attr_names.extract_options!
        options.merge(:attributes => attr_names.flatten)
      end
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?
      errors.clear
      _run_validate_callbacks
      errors.empty?
    end

    # Performs the opposite of <tt>valid?</tt>. Returns true if errors were added, false otherwise.
    def invalid?
      !valid?
    end

    # Hook method defining how an attribute value should be retieved. By default this is assumed
    # to be an instance named after the attribute. Override this method in subclasses should you
    # need to retrieve the value for a given attribute differently e.g.
    #   class MyClass
    #     include ActiveModel::Validations
    #
    #     def initialize(data = {})
    #       @data = data
    #     end
    #
    #     def read_attribute_for_validation(key)
    #       @data[key]
    #     end
    #   end
    #
    alias :read_attribute_for_validation :send
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/validations/#{filename}"
end
