# frozen_string_literal: true

class User
  ADMIN_ROLE = 'admin'

  attr_accessor :id, :role

  def initialize(id:, role:)
    self.id = id
    self.role = role
  end

  def admin?
    role == ADMIN_ROLE
  end
end
