require 'singleton'

module MassiveRecord
  module ORM

    #
    # A factory class for unique IDs for any given tables.
    #
    # Usage:
    #   IdFactory.next_for(:cars) # => 1
    #   IdFactory.next_for(:cars) # => 2
    #   IdFactory.next_for(AClassRespondingToTableName)         # => 1
    #   IdFactory.next_for("a_class_responding_to_table_names") # => 2
    #
    #
    # Storage:
    #   Stored in id_factories table, under column family named tables.
    #   Field name equals to tables it has generated ids for, and it's
    #   values is integers (if the adapter supports it).
    #
    class IdFactory < Table
      include Singleton

      COLUMN_FAMILY_FOR_TABLES = :tables
      ID = "id_factory"

      column_family COLUMN_FAMILY_FOR_TABLES do
        autoload
      end

      #
      # Returns the factory, singleton class.
      # It will be a reloaded version each time instance
      # is retrieved, or else it will fetch self from the
      # database, or if all other fails return a new of self.
      #
      def self.instance
        if table_exists?
          begin
            if @instance
              @instance.reload
            else
              @instance = find(ID)
            end
          rescue RecordNotFound
            @instance = nil
          end
        end

        @instance = new unless @instance
        @instance
      end

      #
      # Delegates to the instance, just a shout cut.
      #
      def self.next_for(table)
        instance.next_for(table)
      end



      #
      # Returns a new and unique id for a given table name
      # Table can a symbol, string or an object responding to table_name
      #
      def next_for(table)
        table = table.respond_to?(:table_name) ? table.table_name : table.to_s
        next_id :table => table
      end



      def id
        ID
      end

      private

      #
      # Method which actually does the increment work for
      # a given table name as string
      #
      def next_id(options = {}) 
        options.assert_valid_keys(:table)
        table_name = options.delete :table

        create_field_or_ensure_type_integer_for(table_name)
        atomic_increment!(table_name)
      end




      def create_field_or_ensure_type_integer_for(table_name)
        if has_field_for? table_name
          ensure_type_integer_for(table_name)
        else
          create_field_for(table_name)
          ensure_that_we_have_table_and_column_families!
        end
      end


      #
      # Creates a field for a table name which is new
      # Feels a bit hackish, hooking in and doing some of what the
      # autoload-functionality of column_family block above does too.
      # But at least, we can "dynamicly" assign new attributes to this object.
      # 
      # TODO  Maybe something the ORM should provide instead and put them in a default
      #       column-family?
      #
      def create_field_for(table_name)
        column_family_for_tables.field(table_name, :integer)
        self.class.attributes_schema = self.class.attributes_schema.merge(column_family_for_tables.fields)
        @attributes[table_name.to_s] = 0
        self.class.undefine_attribute_methods
      end
      
      #
      # Just makes sure that definition of a field is set to integer.
      # This is needed as the autoload functionlaity sets all types to strings.
      #
      def ensure_type_integer_for(table_name)
        column_family_for_tables.fields[table_name].type = :integer
        self[table_name] = 0 if self[table_name].blank?
      end


      def has_field_for?(table_name)
        respond_to? table_name
      end

      def column_family_for_tables
        @column_family_for_tables ||= column_families.detect { |c| c.name == COLUMN_FAMILY_FOR_TABLES }
      end
    end
  end
end