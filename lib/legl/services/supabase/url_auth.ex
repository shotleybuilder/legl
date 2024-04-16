defmodule Legl.Services.Supabase.UrlAuth do
  # https://laqakhlqqmakacqgwrnh.supabase.co/auth/v1/token?grant_type=password

  def url(opts) do
    "auth/v1/token?grant_type=password"
  end
end
