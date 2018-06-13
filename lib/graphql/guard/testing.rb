# frozen_string_literal: true

module GraphQL
  class Field
    NoGuardError = Class.new(StandardError)

    def guard(*args)
      raise NoGuardError.new("Get your field by calling: Type.field_with_guard('#{name}')") unless @__guard_type
      guard_proc = @__guard_object.guard_proc(@__guard_type, self)
      raise NoGuardError.new("Guard lambda does not exist for #{@__guard_type}.#{name}") unless guard_proc

      guard_proc.call(*args)
    end

    def __policy_object=(policy_object)
      @__policy_object = policy_object
      @__guard_object = GraphQL::Guard.new(policy_object: policy_object)
    end

    def __guard_type=(guard_type)
      @__guard_type = guard_type
    end
  end

  class ObjectType
    def field_with_guard(field_name, policy_object = nil)
      field = get_field(field_name)
      return unless field

      field.clone.tap do |f|
        f.__policy_object = policy_object
        f.__guard_type = self
      end
    end
  end

  class Schema
    class Object
      def self.field_with_guard(field_name, policy_object = nil)
        field = fields[field_name]
        return unless field

        field.to_graphql.clone.tap do |f|
          f.__policy_object = policy_object
          f.__guard_type = self.to_graphql
        end
      end
    end
  end
end
