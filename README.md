# graphql-guard

[![Build Status](https://travis-ci.org/exAspArk/graphql-guard.svg?branch=master)](https://travis-ci.org/exAspArk/graphql-guard)
[![Coverage Status](https://coveralls.io/repos/github/exAspArk/graphql-guard/badge.svg)](https://coveralls.io/github/exAspArk/graphql-guard)
[![Code Climate](https://img.shields.io/codeclimate/maintainability/exAspArk/graphql-guard.svg)](https://codeclimate.com/github/exAspArk/graphql-guard/maintainability)
[![Downloads](https://img.shields.io/gem/dt/graphql-guard.svg)](https://rubygems.org/gems/graphql-guard)
[![Latest Version](https://img.shields.io/gem/v/graphql-guard.svg)](https://rubygems.org/gems/graphql-guard)

This gem provides a field-level authorization for [graphql-ruby](https://github.com/rmosolgo/graphql-ruby).

## Contents

* [Usage](#usage)
  * [Inline policies](#inline-policies)
  * [Policy object](#policy-object)
* [Priority order](#priority-order)
* [Integration](#integration)
  * [CanCanCan](#cancancan)
  * [Pundit](#pundit)
* [Error handling](#error-handling)
* [Schema masking](#schema-masking)
* [Installation](#installation)
* [Testing](#testing)
* [Development](#development)
* [Contributing](#contributing)
* [License](#license)
* [Code of Conduct](#code-of-conduct)

## Usage

Define a GraphQL schema:

```ruby
# Define a type
class PostType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: true
end

# Define a query
class QueryType < GraphQL::Schema::Object
  field :posts, [PostType], null: false do
    argument :user_id, ID, required: true
  end

  def posts(user_id:)
    Post.where(user_id: user_id)
  end
end

# Define a schema
class Schema < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
end

# Execute query
Schema.execute(query, variables: { userId: 1 }, context: { current_user: current_user })
```

### Inline policies

Add `GraphQL::Guard` to your schema:

<pre>
class Schema < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
  <b>use GraphQL::Guard.new</b>
end
</pre>

Now you can define `guard` for a field, which will check permissions before resolving the field:

<pre>
class QueryType < GraphQL::Schema::Object
  <b>field :posts</b>, [PostType], null: false do
    argument :user_id, ID, required: true
    <b>guard ->(obj, args, ctx) {</b> args[:user_id] == ctx[:current_user].id <b>}</b>
  end
  ...
end
</pre>

You can also define `guard`, which will be executed for every `*` field in the type:

<pre>
class PostType < GraphQL::Schema::Object
  <b>guard ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>
  ...
end
</pre>

If `guard` block returns `nil` or `false`, then it'll raise a `GraphQL::Guard::NotAuthorizedError` error.

### Policy object

Alternatively, it's possible to extract and describe all policies by using PORO (Plain Old Ruby Object), which should implement a `guard` method. For example:

<pre>
class <b>GraphqlPolicy</b>
  RULES = {
    QueryType => {
      <b>posts: ->(obj, args, ctx) {</b> args[:user_id] == ctx[:current_user].id <b>}</b>
    },
    PostType => {
      <b>'*': ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>
    }
  }

  def self.<b>guard(type, field)</b>
    RULES.dig(type, field)
  end
end
</pre>

Pass this object to `GraphQL::Guard`:

<pre>
class Schema < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
  use GraphQL::Guard.new(<b>policy_object: GraphqlPolicy</b>)
end
</pre>

When using a policy object, you may want to allow [introspection queries](http://graphql.org/learn/introspection/) to skip authorization. A simple way to avoid having to whitelist every introspection type in the `RULES` hash of your policy object is to check the `type` parameter in the `guard` method:

<pre>
def self.guard(type, field)
  <b>type.introspection? ? ->(_obj, _args, _ctx) { true } :</b> RULES.dig(type, field) # or "false" to restrict an access
end
</pre>

## Priority order

`GraphQL::Guard` will use the policy in the following order of priority:

1. Inline policy on the field.
2. Policy from the policy object on the field.
3. Inline policy on the type.
2. Policy from the policy object on the type.

<pre>
class <b>GraphqlPolicy</b>
  RULES = {
    PostType => {
      <b>'*': ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>,                                # <=== <b>4</b>
      <b>title: ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>                               # <=== <b>2</b>
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end

class PostType < GraphQL::Schema::Object
  <b>guard ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>                                    # <=== <b>3</b>
  field :title, String, null: true, <b>guard: ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b> # <=== <b>1</b>
end

class Schema < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
  use GraphQL::Guard.new(<b>policy_object: GraphqlPolicy</b>)
end
</pre>

## Integration

You can simply reuse your existing policies if you really want. You don't need any monkey patches or magic for it ;)

### CanCanCan

<pre>
# Define an ability
class <b>Ability</b>
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    if user.admin?
      can :manage, :all
    else
      can :read, Post, author_id: user.id
    end
  end
end

# Use the ability in your guard
class PostType < GraphQL::Schema::Object
  guard ->(post, args, ctx) { <b>ctx[:current_ability].can?(:read, post)</b> }
  ...
end

# Pass the ability
Schema.execute(query, context: { <b>current_ability: Ability.new(current_user)</b> })
</pre>

### Pundit

<pre>
# Define a policy
class <b>PostPolicy</b> < ApplicationPolicy
  def show?
    user.admin? || record.author_id == user.id
  end
end

# Use the ability in your guard
class PostType < GraphQL::Schema::Object
  guard ->(post, args, ctx) { <b>PostPolicy.new(ctx[:current_user], post).show?</b> }
  ...
end

# Pass current_user
Schema.execute(query, context: { <b>current_user: current_user</b> })
</pre>

## Error handling

By default `GraphQL::Guard` raises a `GraphQL::Guard::NotAuthorizedError` exception if access to the field is not authorized.
You can change this behavior, by passing custom `not_authorized` lambda. For example:

<pre>
class SchemaWithErrors < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
  use GraphQL::Guard.new(
    # By default it raises an error
    # not_authorized: ->(type, field) do
    #   raise GraphQL::Guard::NotAuthorizedError.new("#{type}.#{field}")
    # end

    # Returns an error in the response
    <b>not_authorized: ->(type, field) do
      GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}")
    end</b>
  )
end
</pre>

In this case executing a query will continue, but return `nil` for not authorized field and also an array of `errors`:

<pre>
SchemaWithErrors.execute("query { <b>posts</b>(user_id: 1) { id title } }")
# => {
#   "data" => <b>nil</b>,
#   "errors" => [{
#     "messages" => <b>"Not authorized to access Query.posts"</b>,
#     "locations": { "line" => 1, "column" => 9 },
#     "path" => [<b>"posts"</b>]
#   }]
# }
</pre>

In more advanced cases, you may want not to return `errors` only for some unauthorized fields. Simply return `nil` if user is not authorized to access the field. You can achieve it, for example, by placing the logic into your `PolicyObject`:

<pre>
class <b>GraphqlPolicy</b>
  RULES = {
    PostType => {
      '*': {
        guard: ->(obj, args, ctx) { ... },
        <b>not_authorized:</b> ->(type, field) { GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}") }
      }
      title: {
        guard: ->(obj, args, ctx) { ... },
        <b>not_authorized:</b> ->(type, field) { nil } # simply return nil if not authorized, no errors
      }
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field, :guard)
  end

  def self.<b>not_authorized_handler</b>(type, field)
    RULES</b>.dig(type, field, <b>:not_authorized</b>) || RULES</b>.dig(type, :'*', <b>:not_authorized</b>)
  end
end

class Schema < GraphQL::Schema
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST
  query QueryType
  mutation MutationType

  use GraphQL::Guard.new(
    policy_object: GraphqlPolicy,
    not_authorized: ->(type, field) {
      handler = GraphqlPolicy.<b>not_authorized_handler</b>(type, field)
      handler.call(type, field)
    }
  )
end
</pre>

## Schema masking

It's possible to hide fields from being introspectable and accessible based on the context. For example:

<pre>
class PostType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: true do
    # The field "title" is accessible only for beta testers
    <b>mask ->(ctx) {</b> ctx[:current_user].beta_tester? <b>}</b>
  end
end
</pre>

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graphql-guard'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install graphql-guard

## Testing

It's possible to test fields with `guard` in isolation:

<pre>
# Your type
class QueryType < GraphQL::Schema::Object
  field :posts, [PostType], null: false, <b>guard ->(obj, args, ctx) {</b> ... <b>}</b>
end

# Your test
<b>require "graphql/guard/testing"</b>

posts = QueryType.<b>field_with_guard('posts')</b>
result = posts.<b>guard(obj, args, ctx)</b>
expect(result).to eq(true)
</pre>

If you would like to test your fields with policy objects:


<pre>
# Your type
class QueryType < GraphQL::Schema::Object
  field :posts, [PostType], null: false
end

# Your policy object
class <b>GraphqlPolicy</b>
  def self.<b>guard</b>(type, field)
    <b>->(obj, args, ctx) {</b> ... <b>}</b>
  end
end

# Your test
<b>require "graphql/guard/testing"</b>

posts = QueryType.<b>field_with_guard('posts', GraphqlPolicy)</b>
result = posts.<b>guard(obj, args, ctx)</b>
expect(result).to eq(true)
</pre>

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exAspArk/graphql-guard. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphql::Guard project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/exAspArk/graphql-guard/blob/master/CODE_OF_CONDUCT.md).
