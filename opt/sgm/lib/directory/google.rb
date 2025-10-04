require "google/apis/admin_directory_v1"
require 'googleauth'
require 'googleauth/stores/file_token_store'

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
      if @customer.id == options.css('customer-id').text
        puts "ok"
      else
        throw "directory connection failed"
      end

    end

    def groups
      @client.list_groups(customer: @customer.id).groups.map {|el| el.email.split('@').first }
    end

    def get_members(group)
      @client.list_members(group).members.map {|el| el.email.split('@').first }
    end

  end

end
