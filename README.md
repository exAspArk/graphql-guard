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
  field :posts, [PostType] do
    argument :user_id, !types.ID
    resolve ->(_obj, args, _ctx) { Post.find(args[:user_id]) }
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

### Adding graphql-guard

Add `GraphQL::Guard` to your schema:

```ruby
Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Guard.new # <========= HERE
end
```

Now you can define `guard` for a field, which will check permissions before resolving the field:

```ruby
QueryType = GraphQL::ObjectType.define do
  name "Query"
  field :posts, [PostType] do
    argument :user_id, !types.ID
    guard ->(_obj, args, ctx) { args[:user_id] == ctx[:current_user].id } # <========= HERE
    resolve ->(_obj, args, _ctx) { Post.find(args[:user_id]) }
  end
end
```

You can also define `guard` for each field in the type:

```ruby
PostType = GraphQL::ObjectType.define do
  name "Post"
  guard ->(post, ctx) { post.author?(ctx[:current_user]) || ctx[:current_user].admin? } # <========= HERE
  field :id, !types.ID
  field :title, !types.String
end
```

If `guard` block returns `false`, then it'll raise a `GraphQL::Guard::NotAuthorizedError` error.

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
