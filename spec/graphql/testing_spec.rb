# frozen_string_literal: true

require "spec_helper"

require 'fixtures/user'
require 'fixtures/post'
require 'fixtures/inline_schema'
require 'fixtures/policy_object_schema'

require "graphql/guard/testing"

RSpec.describe GraphQL::Guard do
  context 'inline guard' do
    context 'with a authorizable user' do
      let(:user) { User.new(id: '1', role: 'admin') }

      subject { query_type.field_with_guard('posts').guard(nil, {userId: user.id}, {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:query_type) { Inline::QueryType }

        it 'returns true for an authorized field' do
          expect(subject).to eq(true)
        end
      end

      context 'and using class-based schema' do
        let(:query_type) { Inline::ClassBasedQuery }

        it 'returns true for an authorized field' do
          expect(subject).to eq(true)
        end
      end
    end

    context 'with a not authorizable user' do
      let(:user) { User.new(id: '1', role: 'admin') }

      subject { query_type.field_with_guard('posts').guard(nil, {userId: '2'}, {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:query_type) { Inline::QueryType }

        it 'returns false for a not authorized field' do
          expect(subject).to eq(false)
        end
      end

      context 'and using class-based schema' do
        let(:query_type) { Inline::ClassBasedQuery }

        it 'returns false for a not authorized field' do
          expect(subject).to eq(false)
        end
      end
    end

    context 'with a not admin user' do
      let(:user) { User.new(id: '1', role: 'not_admin') }

      subject { post_type.field_with_guard('id').guard(nil, nil, {current_user: user}) }

      context 'and using legacy-style schema' do
        let(:post_type) { Inline::PostType }

        it 'returns false for a field with a policy on the type' do
          expect(subject).to eq(false)
        end
      end

      context 'and using class-based schema' do
        let(:post_type) { Inline::ClassBasedPost }

        it 'returns false for a not authorized field' do
          expect(subject).to eq(false)
        end
      end
    end
  end

  context 'policy object guard' do
    it 'returns true for an authorized field' do
      posts_field = PolicyObject::QueryType.field_with_guard('posts', PolicyObject::GraphqlPolicy)
      user = User.new(id: '1', role: 'admin')

      result = posts_field.guard(nil, {userId: user.id}, {current_user: user})

      expect(result).to eq(true)
    end

    it 'raises an error if the field is without guard' do
      posts_field = PolicyObject::QueryType.field_with_guard('posts')
      user = User.new(id: '1', role: 'admin')

      expect {
        posts_field.guard(nil, {userId: user.id}, {current_user: user})
      }.to raise_error(GraphQL::Field::NoGuardError, "Guard lambda does not exist for Query.posts")
    end

    it 'raises an error if the field was fetched without guard' do
      posts_field = PolicyObject::QueryType.get_field('posts')
      user = User.new(id: '1', role: 'admin')

      expect {
        posts_field.guard(nil, {userId: user.id}, {current_user: user})
      }.to raise_error(GraphQL::Field::NoGuardError, "Get your field by calling: Type.field_with_guard('posts')")
    end

    it 'returns false for a not authorized field' do
      posts_field = PolicyObject::QueryType.field_with_guard('posts', PolicyObject::GraphqlPolicy)
      user = User.new(id: '1', role: 'admin')

      result = posts_field.guard(nil, {userId: '2'}, {current_user: user})

      expect(result).to eq(false)
    end

    it 'returns false for a field with a policy on the type' do
      posts_field = PolicyObject::PostType.field_with_guard('id', PolicyObject::GraphqlPolicy)
      user = User.new(id: '1', role: 'not_admin')

      result = posts_field.guard(nil, nil, {current_user: user})

      expect(result).to eq(false)
    end
  end
end
