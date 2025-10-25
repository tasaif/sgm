module Sgm

  class Group

    def self.load_from_config
      Group.static_process_groups($config.xpath('/config/groups/group').to_a)
    end

    def self.static_process_groups(group_xml_array)
      l = group_xml_array
      previous_count = l.count
      failed = false
      loop do
        break if l.empty?
        group_config = l.shift
        directory_id = group_config.attr('directory-id')
        msg = "Processing Group: #{group_config[:id]}"
        msg = "Processing Group: #{directory_id}:#{group_config[:id]}" unless directory_id.nil?
        $logger.info(msg)
        if !directory_id.nil?
          directory = Sgm::Directory::Server.all[directory_id]
          directory.ensure_group(group_config['id'])
        else
          group = Group.find_or_create(id: group_config[:id])
          group.update(xml_data: group_config.to_xml)
          group.process
          l.push(group_config) if group.state == 'recalculate'
          break if l.empty?
          if l.count == previous_count
            binding.pry
            $logger.error("Failed to process groups")
            failed = true
            break
          end
          previous_count = l.count
        end
      end
      if failed
        l.each do |group_config|
          group = Group.find_or_create(id: group_config[:id])
          group.update(state: "failed")
        end
      end
    end

    def self.static_process_membership(group, el_membership)
      sym_klass = el_membership.name.split('-').map {|el| el.capitalize}.join.to_sym
      klass = Sgm::Membership.const_get(sym_klass)
      instance = klass.create(xml_data: el_membership.to_xml, group_id: group.id, type: sym_klass)
      return instance.process
    end

    def process
      update(state: 'ok')
      doc.css("/group/*").each do |group_option|
        if group_option.name == 'output-mapping'
          Sgm::OutputMapping.find_or_create(input_group_id: doc.css('group').attr('id').value, output_directory_id: group_option.attr('directory-id'), output_group_directory_id: group_option.text, xml_data:  group_option.to_s)
          next
        end
        result = Group.static_process_membership(self, group_option)
        if result.nil?
          #puts el_membership.to_xml
          update(state: 'recalculate')
          return
        end
      end
    end

    def members
      Member.where(group_id: id).all
    end

    def add_members(members)
      members.each do |member|
        Sgm::Member.find_or_create(group_id: id, member_id: member)
      end
    end

  end

  Group.load_from_config unless $config.nil?

end
