defmodule ExOauth2Provider.Config do
  @moduledoc false

  @spec repo(keyword()) :: module()
  def repo(config), do: get(config, :repo)

  @spec resource_owner(keyword()) :: module()
  def resource_owner(config),
    do: get(config, :resource_owner) || app_module("Users", "User")

  defp app_module(context, module) do
    Module.concat([app_base(otp_app()), context, module])
  end

  @spec access_grant(keyword()) :: module()
  def access_grant(config),
    do: get_oauth_struct(config, :access_grant)

  @spec access_token(keyword()) :: module()
  def access_token(config),
    do: get_oauth_struct(config, :access_token)

  @spec application(keyword()) :: module()
  def application(config),
    do: get_oauth_struct(config, :application)

  defp get_oauth_struct(config, name, namespace \\ "oauth") do
    context = Macro.camelize("#{namespace}_#{name}s")
    module  = Macro.camelize("#{namespace}_#{name}")

    config
    |> get(name)
    |> Kernel.||(app_module(context, module))
  end

  @spec otp_app() :: atom()
  def otp_app(), do: Keyword.fetch!(Mix.Project.config(), :app)

  @doc """
  Fetches the context base module for the app.
  """
  @spec app_base(atom()) :: module()
  def app_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app ->
        app
        |> to_string()
        |> Macro.camelize()
        |> List.wrap()
        |> Module.concat()

      mod ->
        mod
    end
  end

  # Define default access token scopes for your provider
  @spec default_scopes(keyword()) :: [binary()]
  def default_scopes(config),
    do: get(config, :default_scopes, [])

  # Combined scopes list for your provider
  @spec server_scopes(keyword()) :: [binary()]
  def server_scopes(config) do
    config
    |> default_scopes()
    |> Kernel.++(get(config, :optional_scopes, []))
  end

  @spec native_redirect_uri(keyword()) :: binary()
  def native_redirect_uri(config),
    do: get(config, :native_redirect_uri, "urn:ietf:wg:oauth:2.0:oob")

  @spec authorization_code_expires_in(keyword()) :: integer()
  def authorization_code_expires_in(config),
    do: get(config, :authorization_code_expires_in, 600)

  @spec access_token_expires_in(keyword()) :: integer()
  def access_token_expires_in(config),
    do: get(config, :access_token_expires_in, 7200)

  # Issue access tokens with refresh token (disabled by default)
  @spec use_refresh_token?(keyword()) :: boolean()
  def use_refresh_token?(config),
    do: get(config, :use_refresh_token, false)

  # Password auth method to use. Disabled by default. When set, it'll enable
  # password auth strategy. Set config as:
  # `password_auth: {MyModule, :my_auth_method}`
  @spec password_auth(keyword()) :: {atom(), atom()} | nil
  def password_auth(config),
    do: get(config, :password_auth)

  @spec refresh_token_revoked_on_use?(keyword()) :: boolean()
  def refresh_token_revoked_on_use?(config),
    do: get(config, :revoke_refresh_token_on_use, false)

  # Forces the usage of the HTTPS protocol in non-native redirect uris
  # (enabled by default in non-development environments). OAuth2
  # delegates security in communication to the HTTPS protocol so it is
  # wise to keep this enabled.
  @spec force_ssl_in_redirect_uri?(keyword()) :: boolean()
  def force_ssl_in_redirect_uri?(config),
    do: get(config, :force_ssl_in_redirect_uri, Mix.env != :dev)

  # Use a custom access token generator
  @spec access_token_generator(keyword()) :: {atom(), atom()} | nil
  def access_token_generator(config),
    do: get(config, :access_token_generator)

  @spec access_token_response_body_handler(keyword()) :: {atom(), atom()} | nil
  def access_token_response_body_handler(config),
    do: get(config, :access_token_response_body_handler)

  @spec grant_flows(keyword()) :: [binary()]
  def grant_flows(config),
    do: get(config, :grant_flows, ~w(authorization_code client_credentials))

  defp get(config, key, value \\ nil) do
    config
    |> get_from_config(key)
    |> get_from_app_env(key)
    |> get_from_global_env(key)
    |> case do
      :not_found -> value
      value      -> value
    end
  end

  defp get_from_config(config, key), do: Keyword.get(config, key, :not_found)

  defp get_from_app_env(:not_found, key) do
    app = otp_app()

    app
    |> Application.get_env(ExOauth2Provider, [])
    |> case do
      []     -> Application.get_env(app, PhoenixOauth2Provider, [])
      config -> config
    end
    |> Keyword.get(key, :not_found)
  end
  defp get_from_app_env(value, _key), do: value

  defp get_from_global_env(:not_found, key) do
    :ex_oauth2_provider
    |> Application.get_env(ExOAuth2Provider, [])
    |> case do
      []     -> Application.get_env(:phoenix_oauth2_provider, PhoenixOauth2Provider, [])
      config -> config
    end
    |> Keyword.get(key, :not_found)
  end
  defp get_from_global_env(value, _key), do: value
end
