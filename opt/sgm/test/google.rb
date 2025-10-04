#!/usr/bin/env ruby

require "google/apis/admin_directory_v1"
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'pry'

key_file_path = '/run/secrets/ggm-example-473507-caabeb1f3d50.json'
scope = [
  Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP,
  Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY,
  Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_SECURITY
]
credentials = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(key_file_path),
  scope: scope
)
credentials.update!(sub: "tasaif@digital-citizens.org")
credentials.fetch_access_token!
access_token = credentials.access_token

client = Google::Apis::AdminDirectoryV1::DirectoryService.new
client.authorization = access_token
users = client.list_users(customer: 'C04bjnnee')
binding.pry
group_names = client.list_groups(customer: 'C04bjnnee').groups.map {|el| el.name}
unless group_names.include? 'example-group-2'
  client.insert_group(Google::Apis::AdminDirectoryV1::Group.new(name: 'example-group-2', email: 'example-group-2@digital-citizens.org'))
end
