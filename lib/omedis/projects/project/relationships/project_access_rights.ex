defmodule Omedis.Projects.Project.Relationships.ProjectAccessRights do
  @moduledoc """
  A relationship that allows us to access the project access rights for a project.
  """

  use Ash.Resource.ManualRelationship
  use AshPostgres.ManualRelationship

  alias Omedis.AccessRights.AccessRight.Relationships.ResourceAccessRights

  def load(resources, opts, context) do
    ResourceAccessRights.load("Project", resources, opts, context)
  end

  def ash_postgres_join(query, opts, current_binding, as_binding, type, destination_query) do
    ResourceAccessRights.ash_postgres_join(
      "Project",
      query,
      opts,
      current_binding,
      as_binding,
      type,
      destination_query
    )
  end

  def ash_postgres_subquery(opts, current_binding, as_binding, destination_query) do
    ResourceAccessRights.ash_postgres_subquery(
      "Project",
      opts,
      current_binding,
      as_binding,
      destination_query
    )
  end
end
