module Sgm

  class OutputMapping

    def process
      input_group = Group.where(id: input_group_id).first
      output_directory = Sgm::Directory::Server.all[output_directory_id]
      members = output_directory.select_valid_members(input_group.members)
      type = doc.children.last.attr('type') || 'additive'
      case type
      when 'additive'
        output_directory.add_members(output_group_directory_id, members)
      when 'sync'
        output_directory.sync_members(output_group_directory_id, members)
      end
    end

  end

end
