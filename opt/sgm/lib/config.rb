$app_path = File.expand_path("#{File.dirname(__FILE__)}/..")
$config_path = "#{$app_path}/config.xml"
$config = doc = File.open($config_path) { |f| Nokogiri::XML(f) }
