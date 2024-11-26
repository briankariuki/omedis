defmodule OmedisWeb.GroupLive.Show do
  use OmedisWeb, :live_view
  alias Omedis.Accounts.Group

  on_mount {OmedisWeb.LiveHelpers, :maybe_assign_organisation}

  @impl true
  def render(assigns) do
    ~H"""
    <.side_and_topbar
      current_user={@current_user}
      current_organisation={@current_organisation}
      language={@language}
      organisations_count={@organisations_count}
    >
      <div class="px-4 lg:pl-80 lg:pr-8 py-10">
        <.breadcrumb
          items={[
            {dgettext("navigation", "Home"), ~p"/", false},
            {dgettext("navigation", "Organisations"), ~p"/organisations", false},
            {@organisation.name, ~p"/organisations/#{@organisation}", false},
            {dgettext("navigation", "Groups"), ~p"/organisations/#{@organisation}/groups", false},
            {@group.name, "", true}
          ]}
          language={@language}
        />

        <.header>
          <:actions>
            <.link
              patch={~p"/organisations/#{@organisation}/groups/#{@group}/activities"}
              phx-click={JS.push_focus()}
            >
              <.button>
                <%= dgettext("navigation", "Activities") %>
              </.button>
            </.link>
          </:actions>
        </.header>

        <.list>
          <:item title={dgettext("group", "Name")}>
            <%= @group.name %>
          </:item>
          <:item title={dgettext("group", "Slug")}>
            <%= @group.slug %>
          </:item>
        </.list>

        <.back navigate={~p"/organisations/#{@organisation}/groups"}>
          <%= dgettext("navigation", "Back to groups") %>
        </.back>

        <.modal
          :if={@live_action == :edit}
          id="group-modal"
          show
          on_cancel={JS.patch(~p"/organisations/#{@organisation}/groups/#{@group}")}
        >
          <.live_component
            module={OmedisWeb.GroupLive.FormComponent}
            id={@group.id}
            title={@page_title}
            action={@live_action}
            organisation={@organisation}
            language={@language}
            group={@group}
            patch={~p"/organisations/#{@organisation}/groups/#{@group}"}
          />
        </.modal>
      </div>
    </.side_and_topbar>
    """
  end

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    {:ok,
     socket
     |> assign(:language, language)
     |> assign(:page_title, page_title(socket.assigns.live_action))}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       :group,
       Group.by_slug!(group_slug,
         actor: socket.assigns.current_user,
         tenant: socket.assigns.organisation
       )
     )}
  end

  defp page_title(:show),
    do: dgettext("group", "Show Group")

  defp page_title(:edit),
    do: dgettext("group", "Edit Group")
end
