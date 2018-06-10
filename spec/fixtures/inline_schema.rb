# frozen_string_literal: true

module Inline
  PostType = GraphQL::ObjectType.define do
    name "Post"
    guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
    field :id, !types.ID
    field :title, types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :posts, !types[!PostType] do
      argument :userId, !types.ID
      guard ->(_obj, args, ctx) { args[:userId] == ctx[:current_user].id }
      resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:userId]) }
    end

    field :postsWithMask, !types[!PostType] do
      argument :userId, !types.ID
      mask ->(ctx) { ctx[:current_user].admin? }
      resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:userId]) }
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
