load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Apply" do

  def with_script_setup(&block)
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    random_number = rand(100000)

    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("new.sql", "w") do |out|
          out << "create table tmp (id integer);\n"
          out << "insert into tmp (id) values (%s);\n" % [random_number]
        end
        SchemaEvolutionManager::Library.system_or_error("#{add_path} ./new.sql")
        yield db
      end
    end
  end

  it "does not apply sql scripts with dry_run" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      SchemaEvolutionManager::Library.system_or_error("#{apply_path} --url #{db.url} --dry_run")
      lambda {
        db.psql_command("select count(*) from tmp")
      }.should raise_error(RuntimeError)
    end
  end

  it "applies sql scripts without dry_run" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      SchemaEvolutionManager::Library.system_or_error("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from tmp").to_i.should == 1
    end
  end

end
