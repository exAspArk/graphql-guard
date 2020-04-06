module GraphQL
  class Guard
    class FieldExtension < GraphQL::Schema::FieldExtension
      def resolve(object:, arguments:, **rest)
        guard_proc = options[:guard_instance].find_guard_proc(field.owner, field)
        return yield(object, arguments) unless guard_proc

        if guard_proc.call(object, arguments, rest[:context])
          yield(object, arguments)
        else
          options[:guard_instance].not_authorized.call(field.owner, field.name.to_sym)
        end
      end
    end
  end
end
