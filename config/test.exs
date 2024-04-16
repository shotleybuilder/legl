import Config

config :legl,
  supabase_http: [plug: {Req.Test, Legl.Services.Supabase.Http}]

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  level: :debug,
  format: "[$level] $message\n"
