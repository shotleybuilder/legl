import Config

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  level: :warning,
  format: "[$level] $message\n"
