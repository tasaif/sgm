require_relative 'openldap'

module Sgm::Directory::ActiveDirectory

  def self.get_sid_string(data)
    # Ensure the input data is a string of bytes (binary representation)
    return nil unless data.is_a?(String) && !data.empty?
    sid = []
    # Revision level (1 byte)
    sid << data[0].unpack('C').first.to_s
    # Authority (6 bytes)
    authority_bytes = data[2..7].unpack('C*')
    authority = authority_bytes.reduce(0) { |sum, byte| (sum << 8) | byte }
    sid << authority.to_s
    # Sub-authorities (variable length, each 4 bytes)
    # The number of sub-authorities is indicated by the byte at index 1
    num_sub_authorities = data[1].unpack('C').first
    offset = 8 # Start of sub-authorities
    num_sub_authorities.times do
      sub_authority = data[offset, 4].unpack('V').first # 'V' for little-endian unsigned long
      sid << sub_authority.to_s
      offset += 4
    end
    "S-" + sid.join('-')
  end

  class Server < Sgm::Directory::OpenLDAP::Server

    def groups
      retval = []
      filter = Net::LDAP::Filter.eq( "objectClass", "group" )
      treebase = @options.css('groups-base').text
      @connection.search(base: treebase, filter: filter, attributes: ["member"]) do |entry|
        entry.each do |attribute, values|
          next unless attribute == :dn
          retval.push values
        end
      end
      return retval.inject(:+) || []
    end

    def get_members(group_dn)
      retval = []
      group_sid = Sgm::Directory::ActiveDirectory.get_sid_string(@connection.search(base: group_dn).first.objectsid.first)
      group_sid_suffix = group_sid.split('-').last
      treebase = @options.css('users-base').text
      attribute = @options.css('user-unique-attribute').text
      @connection.search(base: treebase, filter: "(|(primaryGroupID=#{group_sid_suffix})(memberOf=#{group_dn}))", attributes: [attribute, :objectClass]).each do |entry|
        if entry.objectclass.include? 'group'
          retval += get_members(entry.dn)
        else
          retval.push entry.instance_variable_get('@myhash')[attribute.downcase.to_sym].first
        end
      end
      return retval
    end

    def ensure_group(group_directory_id)
      return if group_exists? group_directory_id
      group_cn = group_directory_id.downcase.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last
      @connection.add(dn: group_directory_id, attributes: {cn: group_cn, samaccountname: group_cn, objectClass: 'group'})
    end

    def add_members(group_directory_id, members)
      ensure_group(group_directory_id)
      super
    end

    def sync_members(group_directory_id, members)
      ensure_group(group_directory_id)
      member_dns = get_member_dns(members)
      attr = @options.css('user-unique-attribute').text
      group_cn = group_directory_id.downcase.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last

      existing_member_dns = @connection.search(base: group_directory_id, attributes: [:member]).first.instance_variable_get('@myhash')[:member] || []
      members_to_add = member_dns - existing_member_dns
      members_to_remove = existing_member_dns - member_dns
      if members_to_add.count > 0
        @connection.add_attribute(group_directory_id, :member, members_to_add)
      else
        puts "Sync: No members to add for '#{group_directory_id}'"
      end
      if members_to_remove.count > 0
        @connection.modify(dn: group_directory_id, operations: [[:delete, :member, members_to_remove]])
      else
        puts "Sync: No members to remove for '#{group_directory_id}'"
      end

    end

  end

end
