import Config

config :tesla, :adapter, Tesla.Adapter.Hackney

config :phoenix, :json_library, Jason

config :legl, :legislation_gov_uk_api, Legl.Services.LegislationGovUk.Client

config :legl, :supabase_client, Legl.Services.Supabase.Client

# config :floki, :html_parser, Floki.HTMLParser.Html5ever

# Configures Elixir's Logger
config :logger,
       :console,
       format: "$time $metadata[$level] $message\n",
       metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
