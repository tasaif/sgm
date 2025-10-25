def load_config(path)
  doc = File.open(path) { |f| Nokogiri::XML(f) }
  doc.xpath('/config/*').each do |config_element|
    $config.xpath('/config')[0] << config_element
  end
end

$config_path = "#{$app_path}/config.xml"
$config = Nokogiri::XML.parse("<config/>")
load_config($config_path)
