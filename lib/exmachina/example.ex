defmodule Exmachina.Example do
  defstruct pixels: [], labels: []

  def load_examples do
    "lib/examples/semeion.data"
    |> File.stream!()
    |> Enum.map(fn line ->
      row = line |> String.trim("\n") |> String.split(" ")
      pixels = Enum.take(row, 256) |> Enum.map(&String.to_float/1)
      labels = Enum.take(row, -10) |> Enum.map(&String.to_integer/1)

      %__MODULE__{pixels: pixels, labels: labels}
    end)
    |> Enum.shuffle
    |> Enum.with_index
  end

  def load_random_example() do
    load_examples()
    |> List.first
    |> elem(0)
  end
end
