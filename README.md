# graphql-guard

[![Build Status](https://travis-ci.org/exAspArk/graphql-guard.svg?branch=master)](https://travis-ci.org/exAspArk/graphql-guard)
[![Coverage Status](https://coveralls.io/repos/github/exAspArk/graphql-guard/badge.svg)](https://coveralls.io/github/exAspArk/graphql-guard)
[![Code Climate](https://img.shields.io/codeclimate/github/exAspArk/graphql-guard.svg)](https://codeclimate.com/github/exAspArk/graphql-guard)
[![Downloads](https://img.shields.io/gem/dt/graphql-guard.svg)](https://rubygems.org/gems/graphql-guard)
[![Latest Version](https://img.shields.io/gem/v/graphql-guard.svg)](https://rubygems.org/gems/graphql-guard)

This gem provides a field-level authorization for [graphql-ruby](https://github.com/rmosolgo/graphql-ruby).

## Contents

* [Usage](#usage)
  * [Inline policies](#inline-policies)
  * [Policy object](#policy-object)
* [Priority order](#priority-order)
* [Error handling](#error-handling)
* [Integration](#integration)
  * [CanCanCan](#cancancan)
  * [Pundit](#pundit)
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
  field :title, !types.String
end

# Define a query
QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :posts, !types[PostType] do
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

<pre>
Schema = GraphQL::Schema.define do
  query QueryType
  <b>use GraphQL::Guard.new</b>
end
</pre>

Now you can define `guard` for a field, which will check permissions before resolving the field:

<pre>
QueryType = GraphQL::ObjectType.define do
  name "Query"

  <b>field :posts</b>, !types[PostType] do
    argument :user_id, !types.ID
    <b>guard ->(obj, args, ctx) {</b> args[:user_id] == ctx[:current_user].id <b>}</b>
    ...
  end
end
</pre>

You can also define `guard`, which will be executed for every `*` field in the type:

<pre>
PostType = GraphQL::ObjectType.define do
  name "Post"
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
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(<b>policy_object: GraphqlPolicy</b>)
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
      <b>'*': ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>,                           # <=== <b>4</b>
      <b>title: ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>                          # <=== <b>2</b>
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end

PostType = GraphQL::ObjectType.define do
  name "Post"
  <b>guard ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b>                               # <=== <b>3</b>
  <b>field :title</b>, !types.String, <b>guard: ->(obj, args, ctx) {</b> ctx[:current_user].admin? <b>}</b> # <=== <b>1</b>
end

Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(<b>policy_object: GraphqlPolicy</b>)
end
</pre>

## Error handling

By default `GraphQL::Guard` raises a `GraphQL::Guard::NotAuthorizedError` exception if access to field is not authorized.
You can change this behavior, by passing custom `not_authorized` lambda. For example:

<pre>
SchemaWithErrors = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(
    # Returns an error in the response
    <b>not_authorized: ->(type, field) { GraphQL::ExecutionError.new("Not authorized to access #{type}.#{field}") }</b>

    # By default it raises an error
    # not_authorized: ->(type, field) { raise GraphQL::Guard::NotAuthorizedError.new("#{type}.#{field}") }
  )
end
</pre>

In this case executing a query will continue, but return `nil` for not authorized field and also an array of `errors`:

<pre>
SchemaWithErrors.execute("query { <b>posts</b>(user_id: 1) { id title } }")
# => {
#   "data" => <b>nil</b>,
#   "errors" => [{ "messages" => <b>"Not authorized to access Query.posts"</b>, "locations": { ... }, "path" => [<b>"posts"</b>] }]
# }
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
PostType = GraphQL::ObjectType.define do
  name "Post"
  <b>guard ->(post, args, ctx) { ctx[:current_ability].can?(:read, post) }</b>
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
PostType = GraphQL::ObjectType.define do
  name "Post"
  <b>guard ->(post, args, ctx) { PostPolicy.new(ctx[:current_user], post).show? }</b>
  ...
end

# Pass current_user
Schema.execute(query, context: { <b>current_user: current_user</b> })
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
QueryType = GraphQL::ObjectType.define do
  name "Query"
  <b>field :posts</b>, !types[PostType], <b>guard ->(obj, args, ctx) {</b> ... <b>}</b>
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
QueryType = GraphQL::ObjectType.define do
  name "Query"
  <b>field :posts</b>, !types[PostType]
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
