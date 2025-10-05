require "sqlite3"
require 'sequel'
require 'nokogiri'
require 'pry'
require 'active_support/inflector'

Sequel::Model.plugin :timestamps
Sequel::Model.plugin :json_serializer

db_path = "#{$app_path}/#{$config.css('database path').text}"
File.delete(db_path) if File.exist? db_path
$db = SQLite3::Database.new(db_path) unless File.exist? db_path
DB = Sequel.connect("sqlite://#{db_path}")

table_id_type = {
  membership: :Integer,
  member: :Integer,
  output_mapping: :Integer
}

[
  :directory_config,
  :group,
  :member,
  :membership,
  :output_mapping
].each do |name|
  DB.create_table name do
    method((table_id_type[name] || :String)).call :id, primary_key: true
    XMLData :xml_data
  end unless DB.tables.include? name
end

module DbMixins

  def self.included(base)
    base.extend(ClassMethods)  # adds class methods to including class
    base.unrestrict_primary_key
    base.plugin :timestamps, create: :created_at, update: :updated_at
  end

  module ClassMethods

    def deep_find_or_create(data)
      type_mapping = {
        Array: :json
      }
      _data = data.transform_keys(&:to_sym)
      (_data.keys - columns).each do |missing_column|
        DB.alter_table(name.split("::").last.downcase.to_sym) do
          begin
            column_type = type_mapping[_data[missing_column].class.to_s.to_sym]
            add_column missing_column, column_type
          rescue
            binding.pry
          end
        end
        @columns = nil # forces columns method to update based on schema
        set_dataset(dataset)
      end
      lookup = {}
      lookup[primary_key] = _data[primary_key]
      retval = where(lookup).first
      return retval unless retval.nil?
      return create(_data)
    end

    def to_xml
      retval = Nokogiri::XML.parse("<#{table_name.to_s.pluralize}/>").children.last
      all.each do |record|
        retval.add_child(record.to_xml)
      end
      return retval
    end

  end

  def doc
    Nokogiri::XML.parse(xml_data)
  end

  def to_xml
    retval = Nokogiri::XML.parse("<#{self.class.table_name}/>").children.last
    keys.each do |key|
      next if key == :xml_data
      retval.set_attribute(key, self[key])
    end
    return retval
  end

end

table_model_mapping = {
  directory_config: [Sgm::Directory, "Config"],
  group: [Sgm, "Group"],
  membership: [Sgm::Membership, "Base"],
  member: [Sgm, "Member"],
  output_mapping: [Sgm, "OutputMapping"]
}

#
# Note: make sure all columns exist before creating the classes otherwise methods like find_or_create fail
#
DB.add_column(:membership, :group_id, String) unless DB[:membership].columns.include? :group_id
#DB.add_column(:membership, :member_id, String) unless DB[:membership].columns.include? :member_id
DB.add_column(:membership, :type, String) unless DB[:membership].columns.include? :type
DB.add_column(:group, :state, String) unless DB[:group].columns.include? :state
DB.add_column(:member, :group_id, String) unless DB[:member].columns.include? :group_id
DB.add_column(:member, :member_id, String) unless DB[:member].columns.include? :member_id
DB.add_column(:output_mapping, :input_group_id, String) unless DB[:output_mapping].columns.include? :input_group_id
DB.add_column(:output_mapping, :output_group_directory_id, String) unless DB[:output_mapping].columns.include? :output_group_directory_id
DB.add_column(:output_mapping, :output_directory_id, String) unless DB[:output_mapping].columns.include? :output_directory_id

# Dynamically create a model for each table
DB.tables.each do |table|
  unless DB[table].columns.include? :created_at
    DB.add_column table, :created_at, DateTime
    DB.add_column table, :updated_at, DateTime
  end
  _module = Object
  if table_model_mapping[table].nil?
    model_name = table.to_s.split("_").map(&:capitalize).join if model_name.nil?
  else
    __module, model_name = table_model_mapping[table]
    _module = __module unless __module.nil?
  end
  klass = _module.const_set(model_name, Class.new(Sequel::Model(table)))
  klass.include DbMixins
end

class Sgm::Directory::Config

  def instance
    Sgm::Directory::Server.all[id]
  end

end

def get_sequel_models
  ObjectSpace.each_object(Class).select do |klass|
    klass < Sequel::Model rescue false
  end
end
