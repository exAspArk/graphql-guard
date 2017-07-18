require "graphql"
require "graphql/guard/version"

GraphQL::ObjectType.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
GraphQL::Field.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))

module GraphQL
  class Guard
    NotAuthorizedError = Class.new(StandardError)

    def use(schema_definition)
      schema_definition.instrument(:field, self)
    end

    def instrument(type, field)
      guard_proc = guard_proc(type, field)
      return field unless guard_proc

      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(object, arguments, context) do
        raise NotAuthorizedError.new("#{type}.#{field.name}") unless guard_proc.call(object, arguments, context)
        old_resolve_proc.call(object, arguments, context)
      end

      field.redefine { resolve(new_resolve_proc) }
    end

    private

    def guard_proc(type, field)
      field.metadata[:guard] || type.metadata[:guard]
    end
  end
end
