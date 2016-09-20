defmodule RefInspector.Database do
  @moduledoc """
  Referer database.
  """

  use GenServer

  require Logger

  alias RefInspector.Config
  alias RefInspector.Database.State


  # GenServer lifecycle

  @doc """
  Starts the database server.
  """
  @spec start_link() :: GenServer.on_start
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    database_files = Config.database_files
    database_path  = Config.database_path

    state = setup_storage()
    state = Enum.reduce database_files, state, fn (database_file, acc_state) ->
      database = Path.join([ database_path, database_file ])

      { res, new_state } = do_load(database, acc_state)

      case res do
        { :error, reason } -> Logger.info(reason)
        _                  -> nil
      end

      new_state
    end

    { :ok, state }
  end


  # GenServer callbacks

  def handle_call(:ets_tid, _from, state) do
    { :reply, state.ets_tid, state }
  end


  # Convenience methods

  @doc """
  Returns all referer definitions.
  """
  @spec list() :: [tuple]
  def list(), do: GenServer.call(__MODULE__, :ets_tid) |> :ets.tab2list()


  # Internal methods

  def do_load(file, state) do
    case load_file(file) do
      { :error, _ } = error         -> { error, state }
      entries when is_list(entries) -> { :ok, store_refs(entries, state) }
    end
  end

  defp load_file(file) do
    if File.regular?(file) do
      file |> parse_file()
    else
      { :error, "invalid file given: '#{ file }'" }
    end
  end

  defp maybe_hd([]),   do: []
  defp maybe_hd(data), do: hd(data)

  defp parse_file(file) do
    :yamerl_constr.file(file, [ :str_node_as_binary ])
    |> maybe_hd()
    |> parse_entries()
  end

  defp parse_entries(entries), do: parse_entries([], entries)

  defp parse_entries(acc, []), do: Enum.reverse(acc)
  defp parse_entries(acc, [{ medium, sources } | entries ]) do
    sources =
         sources
      |> parse_sources([])
      |> sort_sources()

    parse_entries([{ medium, sources }] ++ acc, entries)
  end

  defp setup_storage() do
    ets_opts = [ :protected, :ordered_set, read_concurrency: true ]
    ets_tid  = :ets.new(:ref_inspector, ets_opts)

    %State{ ets_tid: ets_tid }
  end

  defp store_refs([],                            state), do: state
  defp store_refs([{ medium, sources } | refs ], state)  do
    index   = state.ets_index + 1
    medium  = String.to_atom(medium)
    dataset = { index, medium, sources }

    :ets.insert_new(state.ets_tid, dataset)
    store_refs(refs, %{ state | ets_index: index })
  end


  # Parsing and sorting methods

  defp parse_domains(_,      [],                   acc), do: acc
  defp parse_domains(source, [ domain | domains ], acc)  do
    uri  = URI.parse("http://#{ domain }")
    data =
         source
      |> Map.put(:host, uri.host)
      |> Map.put(:path, uri.path || "/")

    parse_domains(source, domains, acc ++ [ data ])
  end

  defp parse_sources([],                             acc), do: acc
  defp parse_sources([{ name, details } | sources ], acc)  do
    details    = details |> Enum.into(%{})
    domains    = Map.get(details, "domains", [])
    parameters = Map.get(details, "parameters", [])

    source = %{ name: name, parameters: parameters }
    acc    = acc ++ parse_domains(source, domains, [])

    parse_sources(sources, acc)
  end

  defp sort_sources(sources) do
    sources
    |> Enum.map( &Map.put(&1, :sort, "#{ &1.host }#{ &1.path }") )
    |> Enum.sort( &(String.length(&1[:sort]) > String.length(&2[:sort])) )
    |> Enum.uniq_by( &(&1[:sort]) )
    |> Enum.map( &Map.delete(&1, :sort) )
  end
end
