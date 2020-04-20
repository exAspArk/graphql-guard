# frozen_string_literal: true

module GraphQL
  class Field
    NoGuardError = Class.new(StandardError)

    def guard(*args)
      raise NoGuardError.new("Get your field by calling: Type.field_with_guard('#{name}')") unless @__guard_instance

      guard_proc = @__guard_instance.find_guard_proc(@__guard_type, self)
      raise NoGuardError.new("Guard lambda does not exist for #{@__guard_type}.#{name}") unless guard_proc

      guard_proc.call(*args)
    end

    def __set_guard_instance(policy_object, guard_type)
      @__policy_object = policy_object
      @__guard_type = guard_type
      @__guard_instance = GraphQL::Guard.new(policy_object: policy_object)
    end
  end

  class Schema
    class Object
      def self.field_with_guard(field_name, policy_object = nil)
        field = fields[field_name]
        return unless field

        field.to_graphql.clone.tap do |f|
          f.__set_guard_instance(policy_object, self.to_graphql)
        end
      end
    end
  end
end
