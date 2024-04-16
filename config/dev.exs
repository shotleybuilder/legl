import Config

config :legl,
  supabase_client: Legl.Services.Supabase.Client

# Do not include metadata nor timestamps in development logs
config :logger,
       :console,
       level: :info,
       format: "[$level] $message\n"
