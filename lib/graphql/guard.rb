# frozen_string_literal: true

require "graphql"
require "graphql/guard/version"

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
      schema_definition.target.instance_eval do
        def default_filter
          GraphQL::Filter.new(except: default_mask).merge(only: ->(schema_member, ctx) {
            schema_member.metadata[:mask] ? schema_member.metadata[:mask].call(ctx) : true
          })
        end
      end
    end

    def instrument(type, field)
      guard_proc = guard_proc(type, field)
      return field unless guard_proc

      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(object, arguments, context) do
        authorized = guard_proc.call(object, arguments, context)

        if authorized
          old_resolve_proc.call(object, arguments, context)
        else
          not_authorized.call(type, field.name.to_sym)
        end
      end

      field.redefine { resolve(new_resolve_proc) }
    end

    def guard_proc(type, field)
      inline_field_guard(field) ||
        policy_object_guard(type, field.name.to_sym) ||
        inline_type_guard(type) ||
        policy_object_guard(type, ANY_FIELD_NAME)
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

if GraphQL::ObjectType.respond_to?(:accepts_definitions) # GraphQL-Ruby version < 1.8
  GraphQL::ObjectType.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
  GraphQL::Field.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
  GraphQL::Field.accepts_definitions(mask: GraphQL::Define.assign_metadata_key(:mask))
end

if defined?(GraphQL::Schema::Object) && GraphQL::Schema::Object.respond_to?(:accepts_definition) # GraphQL-Ruby version >= 1.8
  GraphQL::Schema::Object.accepts_definition(:guard)
  GraphQL::Schema::Field.accepts_definition(:guard)
  GraphQL::Schema::Field.accepts_definition(:mask)
end
