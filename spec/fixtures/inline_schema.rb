# frozen_string_literal: true

module Inline
  # Schema in legacy-style API
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

  # Schema in class-based API
  class ClassBasedPost < GraphQL::Schema::Object
    guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
    field :id, ID, null: false
    field :title, String, null: true
  end

  class ClassBasedQuery < GraphQL::Schema::Object
    field :posts, [ClassBasedPost], null: false do
      argument :user_id, ID, required: true
      guard ->(_obj, args, ctx) { args[:userId] == ctx[:current_user].id }
    end

    def posts(user_id:)
      Post.where(user_id: user_id)
    end

    field :posts_with_mask, [ClassBasedPost], null: false do
      argument :user_id, ID, required: true
      mask ->(ctx) { ctx[:current_user].admin? }
    end

    def posts_with_mask(user_id:)
      Post.where(user_id: user_id)
    end
  end

  class ClassBasedSchema < GraphQL::Schema
    query ClassBasedQuery
    use GraphQL::Guard.new
  end

  class ClassBasedSchemaWithoutExceptions < GraphQL::Schema
    query ClassBasedQuery
    use GraphQL::Guard.new(not_authorized: ->(type, field) {
      GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}")
    })
  end
end
