# frozen_string_literal: true

module PolicyObject
  case ENV['GRAPHQL_RUBY_VERSION']
  when '1_7'
    PostType = GraphQL::ObjectType.define do
      name "Post"
      field :id, !types.ID
      field :title, types.String
    end

    QueryType = GraphQL::ObjectType.define do
      name "Query"
      field :posts, !types[!PostType] do
        argument :userId, !types.ID
        resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:userId]) }
      end
    end

    class GraphqlPolicy
      RULES = {
        QueryType => {
          posts: ->(_obj, args, ctx) { args[:userId] == ctx[:current_user].id }
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
  when '1_8'
    class PostType < GraphQL::Schema::Object
      field :id, ID, null: false
      field :title, String, null: true
    end

    class QueryType < GraphQL::Schema::Object
      field :posts, [PostType], null: false do
        argument :user_id, ID, required: true
      end

      def posts(user_id:)
        Post.where(user_id: user_id)
      end
    end

    class GraphqlPolicy
      RULES = {
        QueryType => {
          posts: ->(_obj, args, ctx) { args[:userId] == ctx[:current_user].id }
        },
        PostType => {
          '*': ->(_post, args, ctx) { ctx[:current_user].admin? }
        }
      }

      def self.guard(type, field)
        RULES.dig(type.metadata[:type_class], field)
      end
    end

    class Schema < GraphQL::Schema
      query QueryType
      use GraphQL::Guard.new(policy_object: GraphqlPolicy)
    end
  end
end
