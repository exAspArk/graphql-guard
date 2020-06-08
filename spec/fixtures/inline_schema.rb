# frozen_string_literal: true

module Inline
  class PostType < GraphQL::Schema::Object
    guard ->(_post, _args, ctx) { ctx[:current_user].admin? }
    field :id, ID, null: false
    field :title, String, null: true
  end

  class UserType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :role, String, null: false
  end

  class QueryType < GraphQL::Schema::Object
    field :posts, [PostType], null: false do
      argument :user_id, ID, required: true
      guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
    end

    field :posts_with_mask, [PostType], null: false do
      argument :user_id, ID, required: true
      mask ->(ctx) { ctx[:current_user].admin? }
    end

    field :users_with_argument_mask, [UserType], null: false do
      argument :user_id, ID, required: true, mask: ->(ctx) { ctx[:current_user].admin? }
    end

    def posts(user_id:)
      Post.where(user_id: user_id)
    end

    def posts_with_mask(user_id:)
      Post.where(user_id: user_id)
    end

    def users_with_argument_mask(user_id: nil)
      if user_id.nil?
        User.all
      else
        User.all.filter { |u| u.id == user_id.to_i }
      end
    end
  end

  class BaseMutationType < GraphQL::Schema::RelayClassicMutation
  end

  class CreatePostMutation < BaseMutationType
    null true
    argument :user_id, ID, required: true
    field :post, PostType, null: true

    def resolve(user_id:)
      {post: Post.new(user_id: user_id)}
    end
  end

  class MutationType < GraphQL::Schema::Object
    field :create_post, mutation: CreatePostMutation do
      guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
    end
  end

  class Schema < GraphQL::Schema
    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
    query QueryType
    mutation MutationType
    use GraphQL::Guard.new
  end

  class SchemaWithoutExceptions < GraphQL::Schema
    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
    query QueryType
    use GraphQL::Guard.new(not_authorized: ->(type, field) {
      GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}")
    })
  end
end
