load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Init" do

  it "basics" do
    init_path = File.join(Library.base_dir, "bin/sem-init")

    TestUtils.with_bootstrapped_db do |db|
      Library.with_temp_file do |tmp|
        Library.system_or_error("git init #{tmp}")
        Library.system_or_error("#{init_path} --dir #{tmp} --name #{db.name} --user #{db.user}")
      end
    end
  end

end
