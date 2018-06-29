# frozen_string_literal: true

module Inline
  case ENV['GRAPHQL_RUBY_VERSION']
  when '1_7'
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
  when '1_8'
    class PostType < GraphQL::Schema::Object
      guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
      field :id, ID, null: false
      field :title, String, null: true
    end

    class QueryType < GraphQL::Schema::Object
      field :posts, [PostType], null: false do
        argument :user_id, ID, required: true
        guard ->(_obj, args, ctx) { args[:userId] == ctx[:current_user].id }
      end

      field :posts_with_mask, [PostType], null: false do
        argument :user_id, ID, required: true
        mask ->(ctx) { ctx[:current_user].admin? }
      end

      def posts(user_id:)
        Post.where(user_id: user_id)
      end

      def posts_with_mask(user_id:)
        Post.where(user_id: user_id)
      end
    end

    class Schema < GraphQL::Schema
      query QueryType
      use GraphQL::Guard.new
    end

    class SchemaWithoutExceptions < GraphQL::Schema
      query QueryType
      use GraphQL::Guard.new(not_authorized: ->(type, field) {
        GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}")
      })
    end
  end
end
