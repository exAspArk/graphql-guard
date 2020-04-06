# frozen_string_literal: true

module InlineWithoutExceptions
  class PostType < GraphQL::Schema::Object
    guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
    field :id, ID, null: false
    field :title, String, null: true
  end

  class QueryType < GraphQL::Schema::Object
    field :posts, [PostType], null: false do
      argument :user_id, ID, required: true
      guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
    end

    def posts(user_id:)
      Post.where(user_id: user_id)
    end
  end

  class Schema < GraphQL::Schema
    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
    query QueryType
    use GraphQL::Guard.new(not_authorized: ->(type, field) {
      GraphQL::ExecutionError.new("Not authorized to access #{type.graphql_definition}.#{field}")
    })
  end
end
