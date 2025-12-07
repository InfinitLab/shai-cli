# frozen_string_literal: true

FactoryBot.define do
  factory :configuration, class: Hash do
    sequence(:id)
    name { "Test Configuration" }
    slug { "test-configuration" }
    visibility { "private" }
    description { "A test configuration" }
    stars_count { 0 }
    created_at { Time.now.iso8601 }
    updated_at { Time.now.iso8601 }

    initialize_with { attributes.stringify_keys }

    trait :public do
      visibility { "public" }
    end

    trait :starred do
      stars_count { 42 }
    end

    trait :with_owner do
      owner { build(:user) }
    end

    trait :with_tags do
      tags { ["claude", "coding"] }
    end
  end

  factory :tree_node, class: Hash do
    kind { "file" }
    path { ".claude/settings.json" }
    content { '{"model": "claude-3-opus"}' }

    initialize_with { attributes.stringify_keys }

    trait :folder do
      kind { "folder" }
      path { ".claude" }
      content { nil }
    end
  end
end
