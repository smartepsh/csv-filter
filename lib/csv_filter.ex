defmodule CSVFilter do
  @moduledoc """
  Documentation for CSVFilter.
  """
  use Artificery

  alias Artificery.Console

  command :example, "" do
  end

  command :start, "" do
    argument :data_source_file, :string, "The data source file path (csv)", required: true
    argument :target_file, :string, "Target file path", required: true
    argument :filters_file, :string, "Filters file path (csv)", required: false
    option :common_fields, :boolean, "include common fields or not"
    option :async, :boolean, "single process or not"
  end

  def example(_, _) do
    Console.notice "
    ./csv_filter start [--async --common-fields] data_source_file target_file [filters_file]
    "
  end

  def start(_argv, %{} = opts) do
    data_source = Map.get(opts, :data_source_file) |> Path.expand("public")
    data_file = Map.get(opts, :target_file) |> Path.expand("public")
    filters_file = Map.get(opts, :filters_file) |> Path.expand("public")
    csv_filter(filters_file, data_source, data_file)
    Console.success "Done! The file path is #{data_file}"
  end

  def csv_filter(filter_path, file_path, target_file) do
    title = file_path |> read_csv() |> Stream.take(1) |> Enum.to_list() |> List.flatten()

    filters = set_filter(filter_path, title)

    file_path
    |> read_csv()
    |> Stream.map(&apply_filters(&1, filters))
    |> Enum.to_list()
    |> write_csv(target_file)
  end

  def apply_filters(data, filters) do
    filters
    |> Enum.map(&Enum.at(data, &1))
  end

  def set_filter(filter_path, title_line) do
    common_filter = Enum.to_list(0..12)

    title_idxs =
      filter_path
      |> read_csv()
      |> Enum.to_list()
      |> List.flatten()
      |> Enum.reduce(common_filter, fn title, acc ->
        idxs =
          title_line
          |> Enum.with_index()
          |> Enum.filter(fn {node_title, _idx} ->
            String.contains?(node_title, title)
          end)
          |> Enum.map(fn {_, idx} -> idx end)
          |> Enum.uniq()

        idxs ++ acc
      end)
      |> Enum.sort()

    set_idxs(title_idxs, title_line)
  end

  def set_idxs(title_idxs, title_line) do
    IO.inspect(title_idxs)

    title_idxs
    |> Enum.reduce([], fn
      x, acc when x <= 12 ->
        [x | acc]

      x, acc ->
        {_, title_line} = Enum.split(title_line, x + 1)
        {empty_title, _other} = Enum.split_while(title_line, &(&1 == ""))
        Enum.to_list(x..(x + length(empty_title))) ++ acc
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def read_csv(file_path) do
    File.stream!(file_path)
    |> CSV.decode!()
  end

  def write_csv(data, file_path) do
    IO.inspect("start writing")

    file = File.open!(file_path, [:write, :utf8])

    IO.write(file, "\uFEFF")

    data
    |> CSV.encode()
    |> Enum.each(&IO.write(file, &1))
  end
end
