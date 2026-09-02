#!/usr/bin/env sh
set -eu

bundle config unset without || true
bundle install --jobs 4 --retry 3

bundle exec rspec \
  spec/jobs/crm/stale_detector_job_spec.rb \
  spec/jobs/crm/health_check_job_spec.rb \
  spec/controllers/api/v1/accounts/crm/pipelines_controller_spec.rb \
  spec/controllers/api/v1/accounts/crm/activities_controller_spec.rb \
  spec/models/captain_conversation_state_spec.rb \
  spec/services/crm/deal_creator_spec.rb
