# frozen_string_literal: true

require "graphql"
require "graphql/guard/version"

GraphQL::ObjectType.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
GraphQL::Field.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))

module GraphQL
  class Guard
    ANY_FIELD_NAME = :'*'

    NotAuthorizedError = Class.new(StandardError)

    attr_reader :policy_object

    def initialize(policy_object: nil)
      @policy_object = policy_object
    end

    def use(schema_definition)
      schema_definition.instrument(:field, self)
    end

    def instrument(type, field)
      field_guard_proc = inline_field_guard(field) || policy_object_guard(type, field.name.to_sym)
      type_guard_proc = inline_type_guard(type) || policy_object_guard(type, ANY_FIELD_NAME)
      return field if !field_guard_proc && !type_guard_proc

      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(object, arguments, context) do
        authorized =
          if field_guard_proc
            field_guard_proc.call(object, arguments, context)
          elsif type_guard_proc
            type_guard_proc.call(object, context)
          end
        raise NotAuthorizedError.new("#{type}.#{field.name}") unless authorized

        old_resolve_proc.call(object, arguments, context)
      end

      field.redefine { resolve(new_resolve_proc) }
    end

    private

    def policy_object_guard(type, field_name)
      policy_object && policy_object.guard(type, field_name)
    end

    def inline_field_guard(field)
      field.metadata[:guard]
    end

    def inline_type_guard(type)
      type.metadata[:guard]
    end
  end
end
