# frozen_string_literal: true

module WithoutInterpreter
  class QueryType < GraphQL::Schema::Object
    field :userIds, [String], null: false

    def user_ids
      ['1', '2']
    end
  end

  class Schema < GraphQL::Schema
    query QueryType
    use GraphQL::Guard.new
  end
end
