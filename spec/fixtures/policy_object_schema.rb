# frozen_string_literal: true

module PolicyObject
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

  class Schema < GraphQL::Schema
    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
    query QueryType
    use GraphQL::Guard.new(policy_object: GraphqlPolicy)
  end
end
