# frozen_string_literal: true

require "launchy"

module Shai
  module Commands
    module Auth
      DEVICE_FLOW_TIMEOUT = 600 # 10 minutes

      def self.included(base)
        base.class_eval do
          desc "login", "Log in to shaicli.dev"
          option :password, type: :boolean, default: false, desc: "Use password authentication instead of device flow"
          def login
            if options[:password]
              login_with_password
            else
              login_with_device_flow
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

          no_commands do
            def login_with_password
              identifier = ui.ask("Email or username:")
              password = ui.mask("Password:")

              ui.blank

              begin
                response = ui.spinner("Logging in...") do
                  api.login(identifier: identifier, password: password)
                end

                save_credentials_from_response(response)
              rescue AuthenticationError
                ui.error("Invalid credentials")
                exit EXIT_AUTH_REQUIRED
              rescue RateLimitError => e
                ui.error("Too many login attempts. Please try again later.")
                exit EXIT_GENERAL_ERROR
              rescue NetworkError => e
                ui.error(e.message)
                exit EXIT_NETWORK_ERROR
              end
            end

            def login_with_device_flow
              ui.info("Starting device authorization...")
              ui.blank

              begin
                response = api.device_authorize
              rescue RateLimitError => e
                retry_msg = e.retry_after ? " Try again in #{e.retry_after} seconds." : ""
                ui.error("Too many authorization attempts.#{retry_msg}")
                exit EXIT_GENERAL_ERROR
              rescue NetworkError => e
                ui.error(e.message)
                exit EXIT_NETWORK_ERROR
              end

              device_code = response["device_code"]
              user_code = response["user_code"]
              verification_uri = response["verification_uri"]
              verification_uri_complete = response["verification_uri_complete"]
              interval = response["interval"] || 5

              display_device_code_instructions(
                user_code: user_code,
                verification_uri: verification_uri
              )

              ui.blank
              if ui.yes?("Open browser automatically?", default: true)
                open_browser(verification_uri_complete || verification_uri)
              end

              ui.blank
              poll_for_authorization(device_code: device_code, interval: interval)
            end

            def display_device_code_instructions(user_code:, verification_uri:)
              ui.info("To authorize this device:")
              ui.blank
              ui.indent("1. Visit: #{ui.cyan(verification_uri)}")
              ui.indent("2. Enter code: #{ui.bold(user_code)}")
            end

            def open_browser(url)
              Launchy.open(url)
            rescue Launchy::CommandNotFoundError
              ui.warning("Could not open browser automatically. Please visit the URL manually.")
            end

            def poll_for_authorization(device_code:, interval:)
              start_time = Time.now
              current_interval = interval

              spinner = TTY::Spinner.new("[:spinner] Waiting for authorization...", format: :dots)
              spinner.auto_spin

              loop do
                elapsed = Time.now - start_time
                if elapsed > DEVICE_FLOW_TIMEOUT
                  spinner.error
                  ui.error("Authorization timed out. Please try again.")
                  exit EXIT_AUTH_REQUIRED
                end

                sleep(current_interval)

                begin
                  response = api.device_token(device_code: device_code)

                  # Success - we got a token
                  spinner.success
                  save_credentials_from_response(response)
                  return
                rescue DeviceFlowError => e
                  case e.error_code
                  when "authorization_pending"
                    # Keep polling
                    next
                  when "slow_down"
                    current_interval = e.interval || (current_interval + 5)
                    next
                  when "access_denied"
                    spinner.error
                    ui.blank
                    ui.error("Authorization denied by user.")
                    exit EXIT_AUTH_REQUIRED
                  when "expired_token"
                    spinner.error
                    ui.blank
                    ui.error("Device code expired. Please try again.")
                    exit EXIT_AUTH_REQUIRED
                  else
                    spinner.error
                    ui.blank
                    ui.error("Authorization failed: #{e.error_code}")
                    exit EXIT_AUTH_REQUIRED
                  end
                rescue NetworkError => e
                  spinner.error
                  ui.blank
                  ui.error(e.message)
                  exit EXIT_NETWORK_ERROR
                end
              end
            end

            def save_credentials_from_response(response)
              data = response["data"]
              credentials.save(
                token: data["token"],
                expires_at: data["expires_at"],
                user: data["user"]
              )

              ui.blank
              ui.success("Logged in as #{data.dig("user", "username")}")
              ui.indent("Token expires: #{format_date(data["expires_at"])}")
              ui.indent("Token stored in #{Shai.configuration.credentials_path}")
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
