# frozen_string_literal: true

module Inline
  PostType = GraphQL::ObjectType.define do
    name "Post"
    guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
    field :id, !types.ID
    field :title, !types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :posts, !types[!PostType] do
      argument :user_id, !types.ID
      guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
      resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:user_id]) }
    end
  end

  Schema = GraphQL::Schema.define do
    query QueryType
    use GraphQL::Guard.new
  end

  SchemaWithoutExceptions = GraphQL::Schema.define do
    query QueryType
    use GraphQL::Guard.new(not_authorized: ->(type, field) {
      GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}")
    })
  end
end
