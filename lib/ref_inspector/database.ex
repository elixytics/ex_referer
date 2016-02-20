defmodule RefInspector.Database do
  @moduledoc """
  Referer database.
  """

  use GenServer

  alias RefInspector.Database.State


  # GenServer lifecycle

  @doc """
  Starts the database server.
  """
  @spec start_link() :: GenServer.on_start
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_), do: { :ok, %State{} }


  # GenServer callbacks

  def handle_call({ :load, file }, _from, state) do
    case load_file(file) do
      { :error, _ } = error -> { :reply, error, state }

      entries when is_list(entries) ->
        tid   = :ets.new(:ref_inspector, [ :protected, :ordered_set ])
        state = %{ state | ets: tid }

        { :reply, store_refs(entries, state), state }
    end
  end

  def handle_call(:list, _from, state) do
    { :reply, :ets.tab2list(state.ets), state }
  end


  # Convenience methods

  @doc """
  Returns all referer definitions.
  """
  @spec list() :: list
  def list(), do: GenServer.call(__MODULE__, :list)

  @doc """
  Loads a referer database file.
  """
  @spec load(String.t) :: :ok | { :error, String.t }
  def load(nil),  do: :ok
  def load(file), do: GenServer.call(__MODULE__, { :load, file })


  # Internal methods

  defp load_file(file) do
    if File.regular?(file) do
      file |> parse_file()
    else
      { :error, "Invalid file given: '#{ file }'" }
    end
  end

  defp parse_file(file) do
    :yamerl_constr.file(file, [ :str_node_as_binary ])
      |> hd()
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

  defp store_refs([],                            _state), do: :ok
  defp store_refs([{ medium, sources } | refs ], state)   do
    medium  = String.to_atom(medium)
    dataset = { medium, sources }

    :ets.insert_new(state.ets, dataset)
    store_refs(refs, state)
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
    |> Enum.uniq( &(&1[:sort]) )
    |> Enum.map( &Map.delete(&1, :sort) )
  end
end
