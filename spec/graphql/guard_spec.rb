# frozen_string_literal: true

require "spec_helper"

require 'fixtures/user'
require 'fixtures/post'
require 'fixtures/inline_schema'
require 'fixtures/policy_object_schema'

RSpec.describe GraphQL::Guard do
  context 'inline guard' do
    context 'with a valid userId and context' do
      let(:query) { 'query($userId: ID!) { posts(userId: $userId) { id title } }' }
      let(:user) { User.new(id: '1', role: 'admin') }
      let(:result) { {'data' => {'posts' => [{'id' => '1', 'title' => 'Post Title'}]}} }

      subject { schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::Schema }

        it 'authorizes to execute a query' do
          expect(subject).to eq(result)
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchema }

        it 'authorizes to execute a query' do
          expect(subject).to eq(result)
        end
      end
    end

    context 'with sending invalid credential' do
      let(:query) { 'query($userId: ID!) { posts(userId: $userId) { id title } }' }
      let(:user) { User.new(id: '1', role: 'admin') }

      subject { schema.execute(query, variables: {'userId' => '2'}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::Schema }

        it 'does not authorize a field' do
          expect { subject }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Query.posts')
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchema }

        it 'does not authorize a field' do
          expect { subject }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'ClassBasedQuery.posts')
        end
      end
    end

    context 'with sending invalid role' do
      let(:query) { 'query($userId: ID!) { posts(userId: $userId) { id title } }' }
      let(:user) { User.new(id: '1', role: 'not_admin') }

      subject { schema.execute(query, variables: {'userId' => '1'}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::Schema }

        it 'does not authorize a field with a policy on the type' do
          expect { subject }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'Post.id')
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchema }

        it 'does not authorize a field with a policy on the type' do
          expect { subject }.to raise_error(GraphQL::Guard::NotAuthorizedError, 'ClassBasedPost.id')
        end
      end
    end

    context 'with sending invalid role to field' do
      let(:query) { 'query($userId: ID!) { posts(userId: $userId) { id title } }' }
      let(:user) { User.new(id: '1', role: 'not_admin') }

      subject { schema.execute(query, variables: {'userId' => '1'}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::SchemaWithoutExceptions }

        it 'does not authorize a field and returns an error' do
          expect(subject['errors']).to eq([{
            'message' => 'Not authorized to access Post.id',
            'locations' => [{'line' => 1, 'column' => 48}],
            'path' => ['posts', 0, 'id']}
          ])
          expect(subject['data']).to eq(nil)
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchemaWithoutExceptions }

        it 'does not authorize a field and returns an error' do
          expect(subject['errors']).to eq([{
            'message' => 'Not authorized to access ClassBasedPost.id',
            'locations' => [{'line' => 1, 'column' => 48}],
            'path' => ['posts', 0, 'id']}
          ])
          expect(subject['data']).to eq(nil)
        end
      end
    end
  end

  context 'inline mask' do
    context 'with admin role user' do
      let(:query) { 'query($userId: ID!) { postsWithMask(userId: $userId) { id } }' }
      let(:user) { User.new(id: '1', role: 'admin') }

      subject { schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::Schema }

        it 'allows to query a field' do
          expect(subject.to_h).to eq({'data' => {'postsWithMask' => [{'id' => '1'}]}})
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchema }

        it 'allows to query a field' do
          expect(subject.to_h).to eq({'data' => {'postsWithMask' => [{'id' => '1'}]}})
        end
      end
    end

    context 'with not admin role user' do
      let(:query) { 'query($userId: ID!) { postsWithMask(userId: $userId) { id } }' }
      let(:user) { User.new(id: '1', role: 'not_admin') }

      subject { schema.execute(query, variables: {'userId' => user.id}, context: {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:schema) { Inline::Schema }

        it 'hides a field' do
          expect(subject['errors']).to include({
            'message' => %Q(Field 'postsWithMask' doesn't exist on type 'Query'),
            'locations' => [{'line' => 1, 'column' => 23}],
            'fields' => ['query', 'postsWithMask']
          })
        end
      end

      context 'and using class-based schema' do
        let(:schema) { Inline::ClassBasedSchema }

        it 'hides a field' do
          expect(subject['errors']).to include({
            'message' => %Q(Field 'postsWithMask' doesn't exist on type 'ClassBasedQuery'),
            'locations' => [{'line' => 1, 'column' => 23}],
            'fields' => ['query', 'postsWithMask']
          })
        end
      end
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
