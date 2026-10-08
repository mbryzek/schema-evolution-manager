# Run all specs:
./run.rb

This will also install rspec into ../gems directory. Specs create their
databases on postgresql://localhost:5432 unless SEM_TEST_SERVER_URL names
another server (no database name), e.g.

    SEM_TEST_SERVER_URL=postgresql://postgres@localhost:5433 ./run.rb

# Run a specific spec
rspec specs/library_spec.rb
rspec specs/library_spec.rb:12

