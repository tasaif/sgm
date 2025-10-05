module Sgm

  class Group

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
          puts el_membership.to_xml
          update(state: 'recalculate')
          return
        end
      end
    end

    def members
      Member.where(group_id: id).all
    end

  end

  l = $config.xpath('/config/groups/group').to_a
  previous_count = l.count
  loop do
    group_config = l.pop
    group = Group.find_or_create(id: group_config[:id])
    group.update(xml_data: group_config.to_xml)
    group.process
    l.push(group_config) if group.state == 'recalculate'
    break if l.empty?
    binding.pry if l.count == previous_count
    previous_count = l.count
  end

end
