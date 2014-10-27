load File.join(File.dirname(__FILE__), '../init.rb')

describe "SchemaEvolutionManager::Readme" do

  def get_name(line)
    line.strip.sub(/^\-\s*/, '').split.first.strip.sub(/:$/, '')
  end

  it "has correct documentation for migration file attributes" do
    attributes = {}
    current_attribute = nil
    found = 0
    IO.readlines(File.join(File.dirname(__FILE__), '../../README.md')).each do |l|
      if l.strip.downcase == "currently supported attributes:"
        found = 1
      elsif found == 1
        if l.strip.match(/^\#\#/)
          found = 2
        elsif l.match(/^  \- /)
          current_attribute = get_name(l)
          attributes[current_attribute].should be_nil
          attributes[current_attribute] = []
        elsif l.match(/^    \- /)
          attributes[current_attribute] << get_name(l)
        end
      end
    end

    SchemaEvolutionManager::MigrationFile::Attribute::ATTRIBUTES.each do |attr|
      if attributes[attr.name].nil?
        raise "Readme is missing attribute[%s]" % attr.name
      end
        
      readme_values = attributes.delete(attr.name).sort
      if readme_values != attr.valid_values.sort
        raise "Readme has different values for attribute[%s]. Should be[%s] but was[%s]" %
          [attr.name, attr.valid_values.sort.join(" "), readme_values.join(" ")]
      end
    end

    if !attributes.empty?
      raise "Invalid attributes: %s" % attributes.keys.join(" ")
    end
  end

end
