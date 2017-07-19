# frozen_string_literal: true

class Post
  def self.where(user_id:)
    [new(user_id: user_id)]
  end

  attr_accessor :id, :user_id, :title

  def initialize(user_id:)
    self.user_id = user_id
    self.id = 1
    self.title = 'Post Title'
  end
end
