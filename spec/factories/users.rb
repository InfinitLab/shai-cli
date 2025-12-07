# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: Hash do
    id { 1 }
    username { "testuser" }
    display_name { "Test User" }
    avatar_url { nil }

    initialize_with { attributes.stringify_keys }

    trait :with_avatar do
      avatar_url { "https://example.com/avatar.png" }
    end
  end
end
