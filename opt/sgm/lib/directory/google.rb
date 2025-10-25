require "google/apis/admin_directory_v1"
require 'googleauth'
require 'googleauth/stores/file_token_store'

#
# Todo: Use batching when adding members: https://developers.google.com/workspace/admin/directory/v1/guides/batch
#
module Sgm::Directory::Google

  class Server < Sgm::Directory::Server

    def connect
      key_file_path = options.css('cred-file').text
      scope = [
        Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP,
        Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY,
        Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_SECURITY,
        Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_CUSTOMER_READONLY
      ]
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(key_file_path),
        scope: scope
      )
      credentials.update!(sub: options.css('impersonation-user').text)
      credentials.fetch_access_token!
      access_token = credentials.access_token
      @client = Google::Apis::AdminDirectoryV1::DirectoryService.new
      @client.authorization = access_token
      @customer = @client.get_customer(options.css('customer-id').text)
      unless @customer.id == options.css('customer-id').text
        throw "directory connection failed"
      end
      @users_cache ||= @client.list_users(customer: @customer.id)

    end

    #
    # Methods beginning with _ that throw an AuthorizationError are reauthorized and automatically retried
    #
    def method_missing(method_name, *args, &block)
      # Google::Apis::AuthorizationError: Unauthorized (Google::Apis::AuthorizationError)
      _method_name = "_#{method_name.to_s}".to_sym
      if respond_to? _method_name
        begin
          self.send(_method_name, *args, &block)
        rescue Google::Apis::AuthorizationError => e
          puts "Reauthorizing"
          connect
          self.send(_method_name, *args, &block)
        end
      else
        $logger.error("#{_method_name} not implemented")
        throw :method_missing
      end
    end

    def select_valid_members(members)
      member_emails = members.map {|member| "#{member.member_id}@#{@options.css('domain').text}" }
      @users_cache.users.select {|user| member_emails.include?(user.primary_email) }.map {|user| user.primary_email }
    end

    def _groups
      (@client.list_groups(customer: @customer.id).groups || []).map {|el| el.email.split('@').first }
    end

    def _get_members(group_directory_id)
      retval = []
      begin
        response = @client.list_members(group_directory_id)
      rescue Google::Apis::ClientError => e
        if JSON.parse(e.body)['error']['code'] == 404
          $logger.error("group '#{group_directory_id}' not found")
          return nil
        end
        throw e
      end
      @client.list_members(group_directory_id).members.each do |member|
        if member.type == "GROUP"
          retval += get_members(member.email)
        else
          retval.push member.email.split('@').first
        end
      end
      return retval
    end

    def _get_directory_members(group_directory_id)
      (@client.list_members(group_directory_id).members || []).map {|el| el.email}
    end

    def _group_exists?(group_directory_id)
      begin
        @client.get_group(group_directory_id)
      rescue Google::Apis::ClientError => e
        return false if JSON.parse(e.body)['error']['code'] == 404
      end
      return true
    end

    def _ensure_directory_group(group_directory_id)
      if group_exists? group_directory_id
        group = @client.get_group(group_directory_id)
      else
        group = @client.insert_group(Google::Apis::AdminDirectoryV1::Group.new(name: group_directory_id.split('@').first, email: group_directory_id))
      end
    end

    def _add_members(group_directory_id, members)
      ensure_directory_group(group_directory_id)
      _members = members - get_directory_members(group_directory_id)
      if _members.count == 0
        puts "Additive: Noop adding members to '#{group_directory_id}'"
        return
      end
      _members.each do |_member|
        user = @client.get_user(_member)
        @client.insert_member(group_directory_id, user)
      end
    end

    def _sync_members(group_directory_id, members)
      ensure_directory_group(group_directory_id)
      existing_members = get_directory_members(group_directory_id)
      members_to_add = members - existing_members
      members_to_remove = existing_members - members
      members_to_remove.each do |member|
        @client.delete_member(group_directory_id, member)
      end
      members_to_add.each do |member|
        user = @client.get_user(member)
        @client.insert_member(group_directory_id, user)
      end
    end

    def _ensure_group(group_directory_id)
      ensure_directory_group(group_directory_id)
    end

  end

end
