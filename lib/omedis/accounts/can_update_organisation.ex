defmodule Omedis.Accounts.CanUpdateOrganisation do
  @moduledoc """
  Determines whether a user can update an organisation.
  User either needs to be the owner of the organisation or have write access to the organisation through a group.
  """
  use Ash.Policy.SimpleCheck

  import Ash.Query

  alias Omedis.Accounts.AccessRight

  def describe(_options) do
    "User can update or destroy an organisation if they are the owner or have access through a group."
  end

  def match?(nil, _context, _opts), do: false
  def match?(_actor, %{subject: %{data: nil}}, _opts), do: false

  def match?(actor, %{subject: %{data: organisation, action: %{type: :update}}}, _opts) do
    Ash.exists?(
      filter(
        AccessRight,
        resource_name == "Organisation" and
          update && exists(group.group_memberships, user_id == ^actor.id)
      ),
      tenant: organisation
    )
  end

  def match?(actor, %{subject: %{data: organisation, action: %{type: :destroy}}}, _opts) do
    Ash.exists?(
      filter(
        AccessRight,
        resource_name == "Organisation" and
          destroy && exists(group.group_memberships, user_id == ^actor.id)
      ),
      tenant: organisation
    )
  end
end
