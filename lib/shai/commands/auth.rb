# frozen_string_literal: true

module Shai
  module Commands
    module Auth
      def self.included(base)
        base.class_eval do
          desc "login", "Log in to shai.dev"
          def login
            identifier = ui.ask("Email or username:")
            password = ui.mask("Password:")

            ui.blank

            begin
              response = ui.spinner("Logging in...") do
                api.login(identifier: identifier, password: password)
              end

              data = response["data"]
              credentials.save(
                token: data["token"],
                expires_at: data["expires_at"],
                user: data["user"]
              )

              ui.success("Logged in as #{data.dig("user", "username")}")
              ui.indent("Token expires: #{format_date(data["expires_at"])}")
              ui.indent("Token stored in #{Shai.configuration.credentials_path}")
            rescue AuthenticationError
              ui.error("Invalid credentials")
              exit EXIT_AUTH_REQUIRED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "logout", "Log out and remove stored credentials"
          def logout
            credentials.clear
            ui.success("Logged out successfully")
          end

          desc "whoami", "Show current authentication status"
          def whoami
            if credentials.authenticated?
              name = credentials.display_name || credentials.username
              ui.info("Logged in as #{credentials.username} (#{name})")
              ui.info("Token expires: #{format_date(credentials.expires_at)}")
            else
              ui.info("Not logged in. Run `shai login` to authenticate.")
            end
          end
        end
      end

      private

      def format_date(date_string)
        return "unknown" unless date_string

        date = Time.parse(date_string)
        date.strftime("%B %-d, %Y")
      rescue ArgumentError
        date_string
      end
    end
  end
end
