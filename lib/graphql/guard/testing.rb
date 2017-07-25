# frozen_string_literal: true

module GraphQL
  class Field
    NoGuardError = Class.new(StandardError)

    def guard(*args)
      raise NoGuardError.new("Get your field by calling: Type.field_with_guard('#{name}')") unless @guard_type
      guard_proc = @guard_object.field_guard_proc(@guard_type, self) || @guard_object.type_guard_proc(@guard_type, self)
      raise NoGuardError.new("Guard lambda does not exist for #{@guard_type}.#{name}") unless guard_proc

      guard_proc.call(*args)
    end

    def __guard_object=(guard_object)
      @guard_object = guard_object || GraphQL::Guard.new
    end

    def __guard_type=(guard_type)
      @guard_type = guard_type
    end
  end

  class ObjectType
    def field_with_guard(field_name, guard_object = nil)
      field = get_field(field_name)
      return unless field

      field.clone.tap do |f|
        f.__guard_object = guard_object
        f.__guard_type = self
      end
    end
  end
end
