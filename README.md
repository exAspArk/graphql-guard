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

<a href="https://www.universe.com/" target="_blank" rel="noopener noreferrer">
  <img src="images/universe.png" height="41" width="153" alt="Sponsored by Universe" style="max-width:100%;">
</a>

## Usage

Define a GraphQL schema:

```ruby
# Define a type
PostType = GraphQL::ObjectType.define do
  name "Post"

  field :id, !types.ID
  field :title, types.String
end

# Define a query
QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :posts, !types[!PostType] do
    argument :user_id, !types.ID
    resolve ->(obj, args, ctx) { Post.where(user_id: args[:user_id]) }
  end
end

# Define a schema
Schema = GraphQL::Schema.define do
  query QueryType
end

# Execute query
Schema.execute(query, variables: { user_id: 1 }, context: { current_user: current_user })
```

### Inline policies

Add `GraphQL::Guard` to your schema:

```ruby
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new # <=
end
```

Now you can define `guard` for a field, which will check permissions before resolving the field:

```ruby
QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :posts, !types[!PostType] do
    argument :user_id, !types.ID
    guard ->(obj, args, ctx) { args[:user_id] == ctx[:current_user].id } # <=
    ...
  end
end
```

You can also define `guard`, which will be executed for every `*` field in the type:

```ruby
PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(obj, args, ctx) { ctx[:current_user].admin? } # <=
  ...
end
```

If `guard` block returns `nil` or `false`, then it'll raise a `GraphQL::Guard::NotAuthorizedError` error.

### Policy object

Alternatively, it's possible to extract and describe all policies by using PORO (Plain Old Ruby Object), which should implement a `guard` method. For example:

```ruby
class GraphqlPolicy
  RULES = {
    QueryType => {
      posts: ->(obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
    },
    PostType => {
      '*': ->(obj, args, ctx) { ctx[:current_user].admin? }
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end
```

With `graphql-ruby` gem version >= 1.8 and class-based type definitions, `type` doesn't return the actual type class [rmosolgo/graphql-ruby#1429](https://github.com/rmosolgo/graphql-ruby/issues/1429). To get the actual type class:

```ruby
def self.guard(type, field)
  RULES.dig(type.metadata[:type_class], field)
end
```

Pass this object to `GraphQL::Guard`:

```ruby
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(policy_object: GraphqlPolicy) # <=
end
```

When using a policy object, you may want to allow [introspection queries](http://graphql.org/learn/introspection/) to skip authorization. A simple way to avoid having to whitelist every introspection type in the `RULES` hash of your policy object is to check the `type` parameter in the `guard` method:

```ruby
def self.guard(type, field)
  type.introspection? ? ->(_obj, _args, _ctx) { true } : RULES.dig(type, field) # or "false" to restrict an access
end
```

## Priority order

`GraphQL::Guard` will use the policy in the following order of priority:

1. Inline policy on the field.
2. Policy from the policy object on the field.
3. Inline policy on the type.
2. Policy from the policy object on the type.

```ruby
class GraphqlPolicy
  RULES = {
    PostType => {
      '*': ->(obj, args, ctx) { ctx[:current_user].admin? },                           # <=== 4
      title: ->(obj, args, ctx) { ctx[:current_user].admin? }                          # <=== 2
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end

PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(obj, args, ctx) { ctx[:current_user].admin? }                               # <=== 3
  field :title, !types.String, guard: ->(obj, args, ctx) { ctx[:current_user].admin? } # <=== 1
end

Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(policy_object: GraphqlPolicy)
end
```

## Integration

You can simply reuse your existing policies if you really want. You don't need any monkey patches or magic for it ;)

### CanCanCan

```ruby
# Define an ability
class Ability
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
PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(post, args, ctx) { ctx[:current_ability].can?(:read, post) }
  ...
end

# Pass the ability
Schema.execute(query, context: { current_ability: Ability.new(current_user) })
```

### Pundit

```ruby
# Define a policy
class PostPolicy < ApplicationPolicy
  def show?
    user.admin? || record.author_id == user.id
  end
end

# Use the ability in your guard
PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(post, args, ctx) { PostPolicy.new(ctx[:current_user], post).show? }
  ...
end

# Pass current_user
Schema.execute(query, context: { current_user: current_user })
```

## Error handling

By default `GraphQL::Guard` raises a `GraphQL::Guard::NotAuthorizedError` exception if access to the field is not authorized.
You can change this behavior, by passing custom `not_authorized` lambda. For example:

```ruby
SchemaWithErrors = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(
    # By default it raises an error
    # not_authorized: ->(type, field) { raise GraphQL::Guard::NotAuthorizedError.new("#{type}.#{field}") }

    # Returns an error in the response
    not_authorized: ->(type, field) { GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}") }
  )
end
```

In this case executing a query will continue, but return `nil` for not authorized field and also an array of `errors`:

```ruby
SchemaWithErrors.execute("query { posts(user_id: 1) { id title } }")
# => {
#   "data" => nil,
#   "errors" => [{
#     "messages" => "Not authorized to access Query.posts",
#     "locations": { "line" => 1, "column" => 9 },
#     "path" => ["posts"]
#   }]
# }
```

In more advanced cases, you may want not to return `errors` only for some unauthorized fields. Simply return `nil` if user is not authorized to access the field. You can achieve it, for example, by placing the logic into your `PolicyObject`:

```ruby
class GraphqlPolicy
  RULES = {
    PostType => {
      '*': {
        guard: ->(obj, args, ctx) { ... },
        not_authorized: ->(type, field) { GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}") }
      }
      title: {
        guard: ->(obj, args, ctx) { ... },
        not_authorized: ->(type, field) { nil } # simply return nil if not authorized, no errors
      }
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field, :guard)
  end

  def self.not_authorized_handler(type, field)
    RULES.dig(type, field, :not_authorized) || RULES.dig(type, :'*', :not_authorized)
  end
end

Schema = GraphQL::Schema.define do
  query QueryType
  mutation MutationType

  use GraphQL::Guard.new(
    policy_object: GraphqlPolicy,
    not_authorized: ->(type, field) {
      handler = GraphqlPolicy.not_authorized_handler(type, field)
      handler.call(type, field)
    }
  )
end
```

## Schema masking

It's possible to hide fields from being introspectable and accessible based on the context. For example:

```ruby
PostType = GraphQL::ObjectType.define do
  name "Post"

  field :id, !types.ID
  field :title, types.String do
    # The field "title" is accessible only for beta testers
    mask ->(ctx) { ctx[:current_user].beta_tester? }
  end
end
```

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

```ruby
# Your type
QueryType = GraphQL::ObjectType.define do
  name "Query"
  field :posts, !types[!PostType], guard ->(obj, args, ctx) { ... }
end

# Your test
require "graphql/guard/testing"

posts = QueryType.field_with_guard('posts')
result = posts.guard(obj, args, ctx)
expect(result).to eq(true)
```

If you would like to test your fields with policy objects:

```ruby
# Your type
QueryType = GraphQL::ObjectType.define do
  name "Query"
  field :posts, !types[!PostType]
end

# Your policy object
class GraphqlPolicy
  def self.guard(type, field)
    ->(obj, args, ctx) { ... }
  end
end

# Your test
require "graphql/guard/testing"

posts = QueryType.field_with_guard('posts', GraphqlPolicy)
result = posts.guard(obj, args, ctx)
expect(result).to eq(true)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exAspArk/graphql-guard. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphql::Guard project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/exAspArk/graphql-guard/blob/master/CODE_OF_CONDUCT.md).
