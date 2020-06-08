# frozen_string_literal: true

class User
  ADMIN_ROLE = 'admin'
  NOT_ADMIN_ROLE = 'not_admin'

  def self.all
    [new(id: 1), new(id: 2)]
  end

  attr_accessor :id, :role

  def initialize(id:, role: NOT_ADMIN_ROLE)
    self.id = id
    self.role = role
  end

  def admin?
    role == ADMIN_ROLE
  end
end
