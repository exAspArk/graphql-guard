# frozen_string_literal: true

require "graphql"
require "graphql/guard/version"

GraphQL::ObjectType.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
GraphQL::Field.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))

module GraphQL
  class Guard
    ANY_FIELD_NAME = :'*'
    DEFAULT_NOT_AUTHORIZED = ->(type, field) { raise NotAuthorizedError.new("#{type}.#{field}") }

    NotAuthorizedError = Class.new(StandardError)

    attr_reader :policy_object, :not_authorized

    def initialize(policy_object: nil, not_authorized: DEFAULT_NOT_AUTHORIZED)
      @policy_object = policy_object
      @not_authorized = not_authorized
    end

    def use(schema_definition)
      schema_definition.instrument(:field, self)
    end

    def instrument(type, field)
      field_guard_proc = field_guard_proc(type, field)
      type_guard_proc = type_guard_proc(type, field)
      return field if !field_guard_proc && !type_guard_proc

      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(object, arguments, context) do
        authorized =
          if field_guard_proc
            field_guard_proc.call(object, arguments, context)
          elsif type_guard_proc
            type_guard_proc.call(object, context)
          end

        if authorized
          old_resolve_proc.call(object, arguments, context)
        else
          not_authorized.call(type, field.name.to_sym)
        end
      end

      field.redefine { resolve(new_resolve_proc) }
    end

    def field_guard_proc(type, field)
      inline_field_guard(field) || policy_object_guard(type, field.name.to_sym)
    end

    def type_guard_proc(type, field)
      inline_type_guard(type) || policy_object_guard(type, ANY_FIELD_NAME)
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
