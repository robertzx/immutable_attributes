begin
  require 'active_record'
rescue LoadError
  require 'activerecord'
end

module ImmutableErrors
  class ImmutableAttributeError < ActiveRecord::ActiveRecordError
  end
end

module ImmutableAttributes
  VERSION = "1.0.3"
  def attr_immutable(*args)
    class_eval do
      args.each do |attr|
        define_method("#{attr}=") do |value|
          new_record? || read_attribute(attr).nil? ?
            write_attribute(attr, value) :
            raise(ActiveRecord::ImmutableAttributeError, "#{attr} is immutable!")
        end
      end
      # handle ActiveRecord::Base#[]=
      define_method :[]= do |attr, value|
        return write_attribute(attr, value) unless args.include?(attr.to_sym)
        send "#{attr}=", value
      end
    end
  end

  def validates_immutable(*attr_names)
    config = { :on => :update, :if => lambda {|x| true}, :message => "can't be changed" }
    config.update(attr_names.extract_options!)

    @immutables = attr_names

    class_eval do
      def self.immutables
        @immutables
      end
    end

    validates_each(attr_names, config) do |record, attr_name, value|
      old_val, new_val = record.changes[attr_name.to_s]
      record.errors.add(attr_name, config[:message]) unless old_val.nil?
    end
  end
end

ActiveRecord.send :include, ImmutableErrors
ActiveRecord::Base.extend ImmutableAttributes
