module Sgm::Membership

  class Group < Base

    def process
      directory_id = doc.xpath('/group').first['directory-id']
      unless directory_id.nil?
        directory = Sgm::Directory::Server.all[directory_id]
        directory.get_members(doc.text).each do |member|
          Sgm::Member.find_or_create(group_id: group_id, member_id: member)
        end
        return true
      end
      group = Sgm::Group.where(id: doc.text).first
      return nil if group.nil?
      Sgm::Member.where(group_id: group.id).to_a.each do |member|
        Sgm::Member.create(group_id: group_id, member_id: member.member_id)
      end
      return true
    end

  end

end
