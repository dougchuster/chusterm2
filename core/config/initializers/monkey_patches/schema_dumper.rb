# When working with experimental extensions, which doesn't have support on all providers
# This monkey patch will help us to ignore the extensions when dumping the schema
# Additionally we will also ignore the tables associated with those features and exentions

# Once the feature stabilizes, we can remove the tables/extension from the ignore list
# Ensure you write appropriate migrations when you do that.

# Rails 7.2 no longer guarantees that the adapter-specific dumper has been
# loaded while initializers run. Load the class explicitly before reopening it.
require 'active_record/connection_adapters/abstract/schema_dumper'
require 'active_record/connection_adapters/postgresql/schema_dumper'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaDumper
        cattr_accessor :ignore_extensions, default: []

        private

        def extensions(stream)
          extensions = @connection.extensions
          return unless extensions.any?

          stream.puts '  # These extensions should be enabled to support this database'
          extensions.sort.each do |extension|
            stream.puts "  enable_extension #{extension.inspect}" unless ignore_extensions.include?(extension)
          end
          stream.puts
        end
      end
    end
  end
end
