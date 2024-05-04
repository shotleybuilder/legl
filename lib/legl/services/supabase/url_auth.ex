defmodule Legl.Services.Supabase.UrlAuth do
  # https://laqakhlqqmakacqgwrnh.supabase.co/auth/v1/token?grant_type=password

  def url(_opts) do
    # https://supabase.com/docs/reference/self-hosting-auth/password-based-signup-with-either-email-or-phone
    "auth/v1/token?grant_type=password"
  end
end
