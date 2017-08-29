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
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      result = Inline::Schema.execute(query, variables: {'user_id' => user.id}, context: {current_user: user})

      expect(result).to eq({"data" => {"posts" => [{"id" => "1", "title" => "Post Title"}]}})
    end

    it 'does not authorize a field' do
      user = User.new(id: '1', role: 'admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      expect {
        Inline::Schema.execute(query, variables: {'user_id' => '2'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Query.posts')
    end

    it 'does not authorize a field with a policy on the type' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      expect {
        Inline::Schema.execute(query, variables: {'user_id' => '1'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Post.id')
    end

    it 'does not authorize a field and returns an error' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      result = Inline::SchemaWithoutExceptions.execute(query, variables: {'user_id' => '1'}, context: {current_user: user})

      expect(result['errors']).to eq([{
        "message" => "Not authorized to access Post.id",
        "locations" => [{"line" => 1, "column" => 51}],
        "path" => ["posts", 0, "id"]}
      ])
      expect(result['data']).to eq(nil)
    end
  end

  context 'policy object guard' do
    it 'authorizes to execute a query' do
      user = User.new(id: '1', role: 'admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      result = PolicyObject::Schema.execute(query, variables: {'user_id' => user.id}, context: {current_user: user})

      expect(result).to eq({"data" => {"posts" => [{"id" => "1", "title" => "Post Title"}]}})
    end

    it 'does not authorize a field' do
      user = User.new(id: '1', role: 'admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      expect {
        PolicyObject::Schema.execute(query, variables: {'user_id' => '2'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Query.posts')
    end

    it 'does not authorize a field with a policy on the type' do
      user = User.new(id: '1', role: 'not_admin')
      query = "query($user_id: ID!) { posts(user_id: $user_id) { id title } }"

      expect {
        PolicyObject::Schema.execute(query, variables: {'user_id' => '1'}, context: {current_user: user})
      }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Post.id')
    end
  end
end
