# frozen_string_literal: true

require "graphql"
require "graphql/guard/field_extension"
require "graphql/guard/version"

module GraphQL
  class Guard
    NotAuthorizedError = Class.new(StandardError)

    ANY_FIELD_NAME = :'*'

    DEFAULT_NOT_AUTHORIZED = ->(type, field) do
      raise NotAuthorizedError.new("Not authorized to access: #{type.graphql_definition}.#{field}")
    end

    MASKING_FILTER = ->(schema_member, ctx) do
      mask = schema_member.graphql_definition.metadata[:mask]
      mask ? mask.call(ctx) : true
    end

    attr_reader :policy_object, :not_authorized

    def initialize(policy_object: nil, not_authorized: DEFAULT_NOT_AUTHORIZED)
      @policy_object = policy_object
      @not_authorized = not_authorized
    end

    def use(schema_definition)
      if schema_definition.interpreter?
        fields(schema_definition).each do |field|
          field.type_class.extension(GraphQL::Guard::FieldExtension, guard_instance: self)
        end
      else
        raise "Please use the graphql gem version >= 1.10 with GraphQL::Execution::Interpreter"
      end

      add_schema_masking!(schema_definition)
    end

    def find_guard_proc(type, field)
      inline_guard(field) ||
        policy_object_guard(type, field.name.to_sym) ||
        inline_guard(type) ||
        policy_object_guard(type, ANY_FIELD_NAME)
    end

    private

    def fields(schema_definition)
      schema_definition.types.values.flat_map { |type|
        type.fields.values if type.name && type.respond_to?(:fields)
      }.compact
    end

    def add_schema_masking!(schema_definition)
      schema_definition.class_eval do
        def self.default_filter
          GraphQL::Filter.new(except: default_mask).merge(only: MASKING_FILTER)
        end
      end
    end

    def policy_object_guard(type, field_name)
      @policy_object && @policy_object.guard(type.type_class, field_name)
    end

    def inline_guard(type_or_field)
      type_or_field.graphql_definition.metadata[:guard]
    end
  end
end

GraphQL::ObjectType.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
GraphQL::Field.accepts_definitions(guard: GraphQL::Define.assign_metadata_key(:guard))
GraphQL::Field.accepts_definitions(mask: GraphQL::Define.assign_metadata_key(:mask))
GraphQL::Schema::Object.accepts_definition(:guard)
GraphQL::Schema::Field.accepts_definition(:guard)
GraphQL::Schema::Field.accepts_definition(:mask)
