defmodule ExOauth2Provider.Applications.Strategy.Basic do
  @moduledoc """
  The basic postgres-based client_secret application strategy.
  """

  @behaviour ExOauth2Provider.Applications

  import Ecto.Query
  alias Ecto.{Changeset, Schema}
  alias ExOauth2Provider.{AccessTokens, Applications.Application, Config}

  @doc """
  Gets a single application by uid.

  Raises `Ecto.NoResultsError` if the Application does not exist.

  ## Examples

      iex> get_application!("c341a5c7b331ef076eb4954668d54f590e0009e06b81b100191aa22c93044f3d", otp_app: :my_app)
      %OauthApplication{}

      iex> get_application!("75d72f326a69444a9287ea264617058dbbfe754d7071b8eef8294cbf4e7e0fdc", otp_app: :my_app)
      ** (Ecto.NoResultsError)

  """
  @impl true
  @spec get_application!(binary(), keyword()) :: Application.t() | no_return
  def get_application!(uid, config \\ []) do
    config
    |> Config.application()
    |> Config.repo(config).get_by!(uid: uid)
  end

  @doc """
  Gets a single application for a resource owner.

  Raises `Ecto.NoResultsError` if the OauthApplication does not exist for resource owner.

  ## Examples

      iex> get_application_for!(owner, "c341a5c7b331ef076eb4954668d54f590e0009e06b81b100191aa22c93044f3d", otp_app: :my_app)
      %OauthApplication{}

      iex> get_application_for!(owner, "75d72f326a69444a9287ea264617058dbbfe754d7071b8eef8294cbf4e7e0fdc", otp_app: :my_app)
      ** (Ecto.NoResultsError)

  """
  @impl true
  @spec get_application_for!(Schema.t(), binary(), keyword()) :: Application.t() | no_return
  def get_application_for!(resource_owner, uid, config \\ []) do
    config
    |> Config.application()
    |> Config.repo(config).get_by!(owner_id: resource_owner.id, uid: uid)
  end

  @doc """
  Gets a single application by uid.

  ## Examples

      iex> get_application("c341a5c7b331ef076eb4954668d54f590e0009e06b81b100191aa22c93044f3d", otp_app: :my_app)
      %OauthApplication{}

      iex> get_application("75d72f326a69444a9287ea264617058dbbfe754d7071b8eef8294cbf4e7e0fdc", otp_app: :my_app)
      nil

  """
  @impl true
  @spec get_application(binary(), keyword()) :: Application.t() | nil
  def get_application(uid, config \\ []) do
    config
    |> Config.application()
    |> Config.repo(config).get_by(uid: uid)
  end

  @doc """
  Gets a single application by uid and secret.

  ## Examples

      iex> load_application("c341a5c7b331ef076eb4954668d54f590e0009e06b81b100191aa22c93044f3d", "SECRET", otp_app: :my_app)
      %OauthApplication{}

      iex> load_application("75d72f326a69444a9287ea264617058dbbfe754d7071b8eef8294cbf4e7e0fdc", "SECRET", otp_app: :my_app)
      nil

  """
  @impl true
  @spec load_application(
          binary(),
          {:client_secret, binary()} | {:code_verifier, binary()},
          keyword()
        ) :: Application.t() | nil
  def load_application(uid, secret, config \\ [])

  def load_application(uid, {:client_secret, client_secret}, config) do
    config
    |> Config.application()
    |> Config.repo(config).get_by(uid: uid, secret: client_secret)
  end

  def load_application(uid, {:code_verifier, code_verifier}, config) do
    application =
      config
      |> Config.application()
      |> Config.repo(config).get_by(uid: uid)

    case Config.pkce_module(config).verify(application, code_verifier) do
      :ok ->
        application

      {:error, _message} ->
        :invalid_code_verifier
    end
  end

  @doc """
  Returns all applications for a owner.

  ## Examples

      iex> get_applications_for(resource_owner, otp_app: :my_app)
      [%OauthApplication{}, ...]

  """
  @impl true
  @spec get_applications_for(Schema.t(), keyword()) :: [Application.t()]
  def get_applications_for(resource_owner, config \\ []) do
    config
    |> Config.application()
    |> where([a], a.owner_id == ^resource_owner.id)
    |> Config.repo(config).all()
  end

  @doc """
  Gets all authorized applications for a resource owner.

  ## Examples

      iex> get_authorized_applications_for(owner, otp_app: :my_app)
      [%OauthApplication{},...]
  """
  @impl true
  @spec get_authorized_applications_for(Schema.t(), keyword()) :: [Application.t()]
  def get_authorized_applications_for(resource_owner, config \\ []) do
    application_ids =
      resource_owner
      |> AccessTokens.get_authorized_tokens_for(config)
      |> Enum.map(&Map.get(&1, :application_id))

    config
    |> Config.application()
    |> where([a], a.id in ^application_ids)
    |> Config.repo(config).all()
  end

  @doc """
  Create application changeset.

  ## Examples

      iex> change_application(application, %{}, otp_app: :my_app)
      {:ok, %OauthApplication{}}

  """
  @impl true
  @spec change_application(Application.t(), map(), keyword()) :: Changeset.t()
  def change_application(application, attrs \\ %{}, config \\ []) do
    Application.changeset(application, attrs, config)
  end

  @doc """
  Creates an application.

  ## Examples

      iex> create_application(user, %{name: "App", redirect_uri: "http://example.com"}, otp_app: :my_app)
      {:ok, %OauthApplication{}}

      iex> create_application(user, %{name: ""}, otp_app: :my_app)
      {:error, %Ecto.Changeset{}}

  """
  @impl true
  @spec create_application(Schema.t(), map(), keyword()) ::
          {:ok, Application.t()} | {:error, Changeset.t()}
  def create_application(owner, attrs \\ %{}, config \\ []) do
    config
    |> Config.application()
    |> struct(owner: owner)
    |> Application.changeset(attrs, config)
    |> Config.repo(config).insert()
  end

  @doc """
  Updates an application.

  ## Examples

      iex> update_application(application, %{name: "Updated App"}, otp_app: :my_app)
      {:ok, %OauthApplication{}}

      iex> update_application(application, %{name: ""}, otp_app: :my_app)
      {:error, %Ecto.Changeset{}}

  """
  @impl true
  @spec update_application(Application.t(), map(), keyword()) ::
          {:ok, Application.t()} | {:error, Changeset.t()}
  def update_application(application, attrs, config \\ []) do
    application
    |> Application.changeset(attrs, config)
    |> Config.repo(config).update()
  end

  @doc """
  Deletes an application.

  ## Examples

      iex> delete_application(application, otp_app: :my_app)
      {:ok, %OauthApplication{}}

      iex> delete_application(application, otp_app: :my_app)
      {:error, %Ecto.Changeset{}}

  """
  @impl true
  @spec delete_application(Application.t(), keyword()) ::
          {:ok, Application.t()} | {:error, Changeset.t()}
  def delete_application(application, config \\ []) do
    Config.repo(config).delete(application)
  end

  @doc """
  Revokes all access tokens for an application and resource owner.

  ## Examples

      iex> revoke_all_access_tokens_for(application, resource_owner, otp_app: :my_app)
      {:ok, [ok: %OauthAccessToken{}]}

  """
  @impl true
  @spec revoke_all_access_tokens_for(Application.t(), Schema.t(), keyword()) ::
          {:ok, AccessToken.t()} | {:error, any()}
  def revoke_all_access_tokens_for(application, resource_owner, config \\ []) do
    AccessTokens.get_all_tokens_for(resource_owner, application, config)
    |> Enum.map(&AccessTokens.revoke(&1, config))
  end
end
