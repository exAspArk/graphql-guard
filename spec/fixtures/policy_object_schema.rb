# frozen_string_literal: true

module PolicyObject
  PostType = GraphQL::ObjectType.define do
    name "Post"
    field :id, !types.ID
    field :title, !types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :posts, !types[PostType] do
      argument :user_id, !types.ID
      resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:user_id]) }
    end
  end

  class GraphqlPolicy
    RULES = {
      QueryType => {
        posts: ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
      },
      PostType => {
        '*': ->(_post, args, ctx) { ctx[:current_user].admin? }
      }
    }

    def self.guard(type, field)
      RULES.dig(type, field)
    end
  end

  Schema = GraphQL::Schema.define do
    query QueryType
    use GraphQL::Guard.new(policy_object: GraphqlPolicy)
  end
end
