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
      return field unless guard_proc?(type, field)
      old_resolve_proc = field.resolve_proc

      new_resolve_proc =
        if guard_proc = field.metadata[:guard]
          ->(object, arguments, context) do
            raise NotAuthorizedError.new("#{type}.#{field.name}") unless guard_proc.call(object, arguments, context)
            old_resolve_proc.call(object, arguments, context)
          end
        elsif guard_proc = type.metadata[:guard]
          ->(object, arguments, context) do
            raise NotAuthorizedError.new("#{type}.#{field.name}") unless guard_proc.call(object, context)
            old_resolve_proc.call(object, arguments, context)
          end
        end

      field.redefine { resolve(new_resolve_proc) }
    end

    private

    def guard_proc?(type, field)
      !!(field.metadata[:guard] || type.metadata[:guard])
    end
  end
end
