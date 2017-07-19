# graphql-guard

[![Build Status](https://travis-ci.org/exAspArk/graphql-guard.svg?branch=master)](https://travis-ci.org/exAspArk/graphql-guard)

This tiny gem provides a field-level authorization for [graphql-ruby](https://github.com/rmosolgo/graphql-ruby).

## Usage

Define a GraphQL schema:

```ruby
# define type
PostType = GraphQL::ObjectType.define do
  name "Post"
  field :id, !types.ID
  field :title, !types.String
end

# define query
QueryType = GraphQL::ObjectType.define do
  name "Query"
  field :posts, !types[PostType] do
    argument :user_id, !types.ID
    resolve ->(_obj, args, _ctx) { Post.where(user_id: args[:user_id]) }
  end
end

# define schema
Schema = GraphQL::Schema.define do
  query QueryType
end

# execute query
GraphSchema.execute(
  query,
  variables: { user_id: 1 },
  context: { current_user: current_user }
)
```

### Inline policies

Add `GraphQL::Guard` to your schema:

```ruby
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new # <======= ʘ‿ʘ
end
```

Now you can define `guard` for a field, which will check permissions before resolving the field:

```ruby
QueryType = GraphQL::ObjectType.define do
  name "Query"
  field :posts, !types[PostType] do
    argument :user_id, !types.ID
    guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id } # <======= ʘ‿ʘ
    ...
  end
end
```

You can also define `guard`, which will be executed for all fields in the type:

```ruby
PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(_post, ctx) { ctx[:current_user].admin? } # <======= ʘ‿ʘ
  ...
end
```

If `guard` block returns `false`, then it'll raise a `GraphQL::Guard::NotAuthorizedError` error.

### Policy object

Alternatively, it's possible to describe all policies by using PORO (Plain Old Ruby Object), which should implement a `guard` method. For example:

```ruby
class GraphqlPolicy
  RULES = {
    QueryType => {
      posts: ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id }
    },
    PostType => {
      '*': ->(post, ctx) { ctx[:current_user].admin? }
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end
```

Use pass this object to `GraphQL::Guard`:

```ruby
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(policy_object: GraphqlPolicy) # <======= ʘ‿ʘ
end
```

## Order of priority

`GraphQL::Guard` will use the policy in the following order of priority:

1. Inline policy on the field.
2. Policy from the policy object on the field.
3. Inline policy on the type.
2. Policy from the policy object on the type.

```ruby
class GraphqlPolicy
  RULES = {
    PostType => {
      title: ->(_post, ctx) { ctx[:current_user].admin? },                                # <======= 2
      '*': ->(_post, ctx) { ctx[:current_user].admin? }                                   # <======= 4
    }
  }

  def self.guard(type, field)
    RULES.dig(type, field)
  end
end

PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(_post, ctx) { ctx[:current_user].admin? }                                      # <======= 3
  field :title, !types.String, guard: ->(_post, _args, ctx) { ctx[:current_user].admin? } # <======= 1
end

Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new(policy_object: GraphqlPolicy)
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exAspArk/graphql-guard. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphql::Guard project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/exAspArk/graphql-guard/blob/master/CODE_OF_CONDUCT.md).
