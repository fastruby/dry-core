# frozen_string_literal: true

require "dry/core/constants"

module Dry
  module Core
    # Internal support module for class-level settings
    #
    # @api public
    module ClassAttributes
      include Constants
      # Specify what attributes a class will use
      #
      # @example
      #  class ExtraClass
      #    extend Dry::Core::ClassAttributes
      #
      #    defines :hello
      #
      #    hello 'world'
      #  end
      #
      # @example with inheritance and type checking
      #
      #  class MyClass
      #    extend Dry::Core::ClassAttributes
      #
      #    defines :one, :two, type: Integer
      #
      #    one 1
      #    two 2
      #  end
      #
      #  class OtherClass < MyClass
      #    two 3
      #  end
      #
      #  MyClass.one # => 1
      #  MyClass.two # => 2
      #
      #  OtherClass.one # => 1
      #  OtherClass.two # => 3
      #
      # @example with dry-types
      #
      #  class Foo
      #    extend Dry::Core::ClassAttributes
      #
      #    defines :one, :two, type: Dry::Types['strict.int']
      #  end
      #
      # @example with coercion using Proc
      #
      #  class Bar
      #    extend Dry::Core::ClassAttributes
      #
      #    defines :one, coerce: proc { |value| value.to_s }
      #  end
      #
      # @example with coercion using dry-types
      #
      #  class Bar
      #    extend Dry::Core::ClassAttributes
      #
      #    defines :one, coerce: Dry::Types['coercible.string']
      #  end
      #
      def defines(*args, type: ::Object, coerce: IDENTITY)
        unless coerce.respond_to?(:call)
          raise ::ArgumentError, "Non-callable coerce option: #{coerce.inspect}"
        end

        # Readers and the inherited hook are defined from strings so they don't
        # capture closures, which makes them callable from non-main Ractors.
        # The writer needs `type` and `coerce`, so it stays a block.
        mod = ::Module.new do
          args.each do |name|
            ivar = :"@#{name}"
            setter = :"__set_#{name}__"

            define_method(setter) do |value|
              if type === value # rubocop:disable Style/CaseEquality
                instance_variable_set(ivar, coerce.call(value))
              else
                raise InvalidClassAttributeValueError.new(name, value)
              end
            end
            private setter

            module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def #{name}(value = ::Dry::Core::Constants::Undefined)
                if ::Dry::Core::Constants::Undefined.equal?(value)
                  #{ivar}
                else
                  #{setter}(value)
                end
              end
            RUBY
          end

          module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
            def inherited(klass)
              #{args.inspect}.each { |name| klass.send(name, send(name)) }

              super
            end
          RUBY
        end

        extend(mod)
      end
    end
  end
end
