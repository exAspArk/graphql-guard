# frozen_string_literal: true

require "spec_helper"

require 'fixtures/user'
require 'fixtures/post'
require 'fixtures/inline_schema'
require 'fixtures/policy_object_schema'

require "graphql/guard/testing"

RSpec.describe GraphQL::Guard do
  context 'inline guard' do
    it 'returns true for an authorized field' do
      posts_field = Inline::QueryType.field_with_guard('posts')
      user = User.new(id: '1', role: 'admin')

      result = posts_field.guard(nil, {userId: user.id}, {current_user: user})

      expect(result).to eq(true)
    end

    it 'returns false for a not authorized field' do
      posts_field = Inline::QueryType.field_with_guard('posts')
      user = User.new(id: '1', role: 'admin')

      result = posts_field.guard(nil, {userId: '2'}, {current_user: user})

      expect(result).to eq(false)
    end

    it 'returns false for a field with a policy on the type' do
      posts_field = Inline::PostType.field_with_guard('id')
      user = User.new(id: '1', role: 'not_admin')

      result = posts_field.guard(nil, nil, {current_user: user})

      expect(result).to eq(false)
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

    if ENV['GRAPHQL_RUBY_VERSION'] == '1_7'
    it 'raises an error if the field was fetched without guard' do
      posts_field = PolicyObject::QueryType.get_field('posts')
      user = User.new(id: '1', role: 'admin')

      expect {
        posts_field.guard(nil, {userId: user.id}, {current_user: user})
      }.to raise_error(GraphQL::Field::NoGuardError, "Get your field by calling: Type.field_with_guard('posts')")
    end
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
