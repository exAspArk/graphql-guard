# frozen_string_literal: true

require "spec_helper"

require 'fixtures/user'
require 'fixtures/post'
require 'fixtures/inline_schema'
require 'fixtures/policy_object_schema'

RSpec.describe GraphQL::Guard do
  context 'inline guard' do
    it 'authorizes to execute a query' do
      user = User.new(id: '1', role: 'admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      result = Inline::Schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user})

      expect(result).to eq({"data" => {"posts" => [{"id" => "1", "title" => "Post Title"}]}})
    end

    it 'does not authorize a field' do
      user = User.new(id: '1', role: 'admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      expect {
        Inline::Schema.execute(query, variables: {'userId' => '2'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Query.posts')
    end

    it 'does not authorize a field with a policy on the type' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      expect {
        Inline::Schema.execute(query, variables: {'userId' => '1'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Post.id')
    end

    it 'does not authorize a field and returns an error' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      result = Inline::SchemaWithoutExceptions.execute(query, variables: {'userId' => '1'}, context: {current_user: user})

      expect(result['errors']).to eq([{
        "message" => "Not authorized to access Post.id",
        "locations" => [{"line" => 1, "column" => 48}],
        "path" => ["posts", 0, "id"]}
      ])
      expect(result['data']).to eq(nil)
    end
  end

  context 'inline mask' do
    it 'allows to query a field' do
      user = User.new(id: '1', role: 'admin')
      query = "query($userId: ID!) { postsWithMask(userId: $userId) { id } }"

      result = Inline::Schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user})

      expect(result.to_h).to eq({"data" => {"postsWithMask" => [{"id" => "1"}]}})
    end

    it 'hides a field' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($userId: ID!) { postsWithMask(userId: $userId) { id } }"

      result = Inline::Schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user})

      expect(result['errors']).to include({
        "message" => "Field 'postsWithMask' doesn't exist on type 'Query'",
        "locations" => [{"line" => 1, "column" => 23}],
        "fields" => ["query", "postsWithMask"]
      })
    end
  end

  context 'policy object guard' do
    it 'authorizes to execute a query' do
      user = User.new(id: '1', role: 'admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      result = PolicyObject::Schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user})

      expect(result).to eq({"data" => {"posts" => [{"id" => "1", "title" => "Post Title"}]}})
    end

    it 'does not authorize a field' do
      user = User.new(id: '1', role: 'admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      expect {
        PolicyObject::Schema.execute(query, variables: {'userId' => '2'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Query.posts')
    end

    it 'does not authorize a field with a policy on the type' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($userId: ID!) { posts(userId: $userId) { id title } }"

      expect {
        PolicyObject::Schema.execute(query, variables: {'userId' => '1'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Post.id')
    end
  end
end
