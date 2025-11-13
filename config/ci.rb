# Run using bin/ci
# This configuration runs all CI checks locally before pushing to GitHub.
# The same checks are run in GitHub Actions for automated CI/CD.

CI.run do
  # Setup: Install dependencies and prepare environment
  step "Setup: Install dependencies", "bin/setup --skip-server"

  # Code Quality: Style and linting
  step "Style: Ruby code with Rubocop", "bin/rubocop"

  # Security: Vulnerability scans
  step "Security: JavaScript dependency audit", "bin/importmap audit"
  step "Security: Rails vulnerability scan", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # Database: Prepare and validate
  step "Database: Prepare test database", "bin/rails db:test:prepare"

  # Tests: Run test suite
  step "Tests: RSpec test suite", "bundle exec rspec"

  # Tests: Validate database seeds
  step "Tests: Database seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: Asset compilation check (uncomment if needed)
  # step "Assets: Compile CSS", "bin/rails css:build"

  # Optional: GitHub PR signoff
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
