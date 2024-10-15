defmodule OmedisWeb.TenantLive.Today do
  use OmedisWeb, :live_view
  alias Omedis.Accounts.Group
  alias Omedis.Accounts.LogCategory
  alias Omedis.Accounts.LogEntry
  alias Omedis.Accounts.Project
  alias Omedis.Accounts.Tenant

  @impl true
  def render(assigns) do
    ~H"""
    <.side_and_topbar
      current_user={@current_user}
      current_tenant={@current_tenant}
      language={@language}
      tenants_count={@tenants_count}
    >
      <div class="px-4 lg:pl-80 lg:pr-8 py-10">
        <.breadcrumb items={[
          {"Home", ~p"/", false},
          {"Tenants", ~p"/tenants", false},
          {@tenant.name, ~p"/tenants/#{@tenant.slug}", false},
          {"Groups", ~p"/tenants/#{@tenant.slug}/groups", false},
          {@group.name, ~p"/tenants/#{@tenant.slug}/groups/#{@group.slug}", false},
          {"Today", "", true}
        ]} />

        <.select_for_groups_and_project
          groups={@groups}
          group={@group}
          project={@project}
          language={@language}
          projects={@projects}
          header_text={with_locale(@language, fn -> gettext("Select group and project") end)}
        />

        <.dashboard_component
          categories={@categories}
          start_at={@start_at}
          end_at={@end_at}
          log_entries={@log_entries}
          language={@language}
          current_time={@current_time}
        />
      </div>
    </.side_and_topbar>
    """
  end

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    {:ok,
     socket
     |> assign(:language, language)}
  end

  @impl true
  def handle_params(%{"group_id" => id, "project_id" => project_id, "slug" => slug}, _, socket) do
    tenant = Tenant.by_slug!(slug)
    group = Group.by_id!(id)
    project = Project.by_id!(project_id)

    {min_start_in_entries, max_end_in_entries} =
      get_time_range(LogEntry.by_tenant_today!(%{tenant_id: tenant.id}))

    start_at =
      get_start_time_to_use(min_start_in_entries, tenant.daily_start_at)
      |> format_timezone(tenant.timezone)
      |> round_down_start_at()

    end_at =
      get_end_time_to_use(max_end_in_entries, tenant.daily_end_at)
      |> format_timezone(tenant.timezone)
      |> round_up_end_at()

    update_categories_and_current_time_every_minute()

    categories = categories(group.id, project.id)

    log_entries = format_entries(categories, tenant)

    current_time = Time.utc_now() |> format_timezone(tenant.timezone)

    {:noreply,
     socket
     |> assign(:page_title, "Today")
     |> assign(:tenant, tenant)
     |> assign(:start_at, start_at)
     |> assign(:end_at, end_at)
     |> assign(:groups, groups_for_a_tenant(tenant.id))
     |> assign(:projects, projects_for_a_tenant(tenant.id))
     |> assign(:group, group)
     |> assign(:project, project)
     |> assign(:log_entries, log_entries)
     |> assign(:current_time, current_time)
     |> assign(:categories, categories)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    tenant = Tenant.by_slug!(slug)
    group = latest_group_for_a_tenant(tenant.id)
    project = latest_project_for_a_tenant(tenant.id)

    {:noreply,
     socket
     |> push_navigate(
       to: "/tenants/#{tenant.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
     )}
  end

  # Defaults to German Timezone
  defp format_timezone(time, nil), do: Time.add(time, 2, :hour)

  defp format_timezone(time, timezone) do
    regex = ~r/GMT([+-]\d{2})/

    offset =
      case Regex.run(regex, timezone) do
        # Convert the extracted "+03" into an integer (+3)
        [_, offset] -> String.to_integer(offset)
        _ -> "No match"
      end

    Time.add(time, offset, :hour)
  end

  @impl true
  def handle_info(:update_categories_and_current_time, socket) do
    tenant = socket.assigns.tenant
    group = socket.assigns.group
    project = socket.assigns.project

    categories = categories(group.id, project.id)

    log_entries =
      format_entries(categories, tenant)

    {min_start_in_entries, max_end_in_entries} =
      get_time_range(LogEntry.by_tenant_today!(%{tenant_id: tenant.id}))

    start_at =
      get_start_time_to_use(min_start_in_entries, tenant.daily_start_at)
      |> format_timezone(tenant.timezone)
      |> round_down_start_at()

    end_at =
      get_end_time_to_use(max_end_in_entries, tenant.daily_end_at)
      |> format_timezone(tenant.timezone)
      |> round_up_end_at()

    current_time = Time.utc_now() |> format_timezone(tenant.timezone)

    {:noreply,
     socket
     |> assign(:categories, categories)
     |> assign(:log_entries, log_entries)
     |> assign(:start_at, start_at)
     |> assign(:end_at, end_at)
     |> assign(:current_time, current_time)}
  end

  defp update_categories_and_current_time_every_minute do
    :timer.send_interval(1000, self(), :update_categories_and_current_time)
  end

  defp get_start_time_to_use(nil, tenant_daily_start_at) do
    tenant_daily_start_at
  end

  defp get_start_time_to_use(min_start_in_entries, tenant_daily_start_at) do
    if Time.compare(min_start_in_entries, tenant_daily_start_at) == :lt do
      min_start_in_entries
    else
      tenant_daily_start_at
    end
  end

  defp get_end_time_to_use(nil, tenant_daily_end_at) do
    tenant_daily_end_at
  end

  defp get_end_time_to_use(max_end_in_entries, tenant_daily_end_at) do
    if Time.compare(max_end_in_entries, tenant_daily_end_at) == :gt do
      max_end_in_entries
    else
      tenant_daily_end_at
    end
  end

  defp format_entries(categories, tenant) do
    categories
    |> Enum.map(fn category ->
      category.log_entries
    end)
    |> List.flatten()
    |> Enum.filter(fn entry ->
      entry.created_at |> DateTime.to_date() == Date.utc_today()
    end)
    |> Enum.sort_by(fn %{start_at: start_at, end_at: end_at} -> {start_at, end_at} end)
    |> Enum.map(fn x ->
      %{
        id: x.id,
        start_at: x.start_at |> format_timezone(tenant.timezone),
        end_at: get_end_time_in_entry(x.end_at) |> format_timezone(tenant.timezone),
        category_id: x.log_category_id,
        color_code:
          Enum.find(categories, fn category ->
            category.log_entries |> Enum.find(fn entry -> entry.start_at == x.start_at end)
          end).color_code
      }
    end)
  end

  defp get_end_time_in_entry(nil) do
    Time.utc_now()
  end

  defp get_end_time_in_entry(end_time) do
    end_time
  end

  defp categories(group_id, project_id) do
    case LogCategory.by_group_id_and_project_id(%{group_id: group_id, project_id: project_id}) do
      {:ok, %{results: categories}} ->
        categories

      _ ->
        []
    end
  end

  defp get_time_range(log_entries) do
    log_entries =
      log_entries
      |> Enum.map(fn x ->
        %{
          start_at: x.start_at,
          end_at: get_end_time_in_entry(x.end_at)
        }
      end)

    Enum.reduce(log_entries, {nil, nil}, fn entry, {min_start, max_end} ->
      start_at = entry.start_at
      end_at = entry.end_at

      min_start = get_min_start(min_start, start_at)

      max_end =
        get_max_end(max_end, end_at)

      {
        min_start,
        max_end
      }
    end)
  end

  defp get_min_start(min_start, start_at) do
    case min_start do
      nil -> start_at
      _ -> if Time.compare(start_at, min_start) == :lt, do: start_at, else: min_start
    end
  end

  defp get_max_end(max_end, end_at) do
    case max_end do
      nil -> end_at
      _ -> if Time.compare(end_at, max_end) == :gt, do: end_at, else: max_end
    end
  end

  def round_down_start_at(start_at) do
    Time.new!(start_at.hour, 0, 0)
  end

  def round_up_end_at(end_at) do
    if end_at.minute > 0 or end_at.second > 0 do
      Time.add(Time.new!(end_at.hour, 0, 0), 3600, :second)
    else
      Time.new!(end_at.hour, 0, 0)
    end
  end

  @impl true

  def handle_event("select_log_category", %{"log_category_id" => log_category_id}, socket) do
    create_or_stop_log_entry(
      log_category_id,
      socket.assigns.tenant.id,
      socket.assigns.current_user.id
    )

    {:noreply,
     socket
     |> assign(:categories, categories(socket.assigns.group.id, socket.assigns.project.id))}
  end

  def handle_event("select_group", %{"group_id" => id}, socket) do
    {:noreply,
     socket
     |> push_navigate(
       to:
         "/tenants/#{socket.assigns.tenant.slug}/today?group_id=#{id}&project_id=#{socket.assigns.project.id}"
     )}
  end

  def handle_event("select_project", %{"project_id" => id}, socket) do
    {:noreply,
     socket
     |> push_navigate(
       to:
         "/tenants/#{socket.assigns.tenant.slug}/today?group_id=#{socket.assigns.group.id}&project_id=#{id}"
     )}
  end

  defp create_or_stop_log_entry(log_category_id, tenant_id, user_id) do
    {:ok, log_entries} = LogEntry.by_log_category_today(%{log_category_id: log_category_id})

    case Enum.find(log_entries, fn log_entry -> log_entry.end_at == nil end) do
      nil ->
        stop_any_active_log_entry(tenant_id)
        create_log_entry(log_category_id, tenant_id, user_id)

      log_entry ->
        create_or_stop_log_entry(log_entry, log_category_id)
    end
  end

  defp create_or_stop_log_entry(log_entry, log_category_id) do
    if log_entry.log_category_id == log_category_id do
      stop_log_entry(log_entry)
    else
      stop_log_entry(log_entry)
      create_log_entry(log_category_id, log_entry.tenant_id, log_entry.user_id)
    end
  end

  defp stop_any_active_log_entry(tenant_id) do
    {:ok, log_entries} = LogEntry.by_tenant(%{tenant_id: tenant_id})

    case Enum.find(log_entries, fn log_entry -> log_entry.end_at == nil end) do
      nil ->
        :ok

      log_entry ->
        stop_log_entry(log_entry)
    end
  end

  defp create_log_entry(log_category_id, tenant_id, user_id) do
    LogEntry.create(%{
      log_category_id: log_category_id,
      tenant_id: tenant_id,
      user_id: user_id,
      start_at: Time.utc_now()
    })
  end

  def stop_log_entry(log_entry) do
    LogEntry.update(log_entry, %{end_at: Time.utc_now()})
  end

  defp latest_group_for_a_tenant(tenant_id) do
    case Group.by_tenant_id(%{tenant_id: tenant_id}) do
      {:ok, %{results: groups}} ->
        Enum.min_by(groups, & &1.created_at)

      _ ->
        %{
          id: ""
        }
    end
  end

  defp latest_project_for_a_tenant(tenant_id) do
    case Project.by_tenant_id(%{tenant_id: tenant_id}) do
      {:ok, projects} ->
        Enum.min_by(projects, & &1.created_at)

      _ ->
        %{
          id: ""
        }
    end
  end

  defp groups_for_a_tenant(tenant_id) do
    case Group.by_tenant_id(%{tenant_id: tenant_id}) do
      {:ok, %{results: groups}} ->
        groups
        |> Enum.map(fn group -> {group.name, group.id} end)

      _ ->
        []
    end
  end

  defp projects_for_a_tenant(tenant_id) do
    case Project.by_tenant_id(%{tenant_id: tenant_id}) do
      {:ok, projects} ->
        projects
        |> Enum.map(fn project -> {project.name, project.id} end)

      _ ->
        []
    end
  end
end
