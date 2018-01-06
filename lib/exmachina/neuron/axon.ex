defmodule Exmachina.Neuron.Axon do
  alias Exmachina.Neuron

  defstruct output_weights: %{}, responses: %{}

  def new([]), do: %__MODULE__{}
  def new(output_pids) do
    output_weights = output_pids
      |> Enum.map(& {&1, init_weight()})
      |> Enum.into(%{})

    %__MODULE__{output_weights: output_weights}
  end

  def send_and_receive(messages, %__MODULE__{} = axon) do
    responses = messages
      |> Task.async_stream(fn {output_pid, message} ->
        response = Neuron.activate(output_pid, message)
        {output_pid, response}
      end, max_concurrency: 999)
      |> Enum.map(fn {:ok, val} -> val end)
      |> Enum.into(%{})

    %{axon | responses: responses}
  end

  def adjust_weights(adjustments, %__MODULE__{output_weights: output_weights} = axon) do
    new_weights = adjustments
      |> Enum.map(fn {output_pid, adjustment} ->
        old_weight = output_weights[output_pid]
        new_weight = old_weight + adjustment
        {output_pid, new_weight}
      end)
      |> Enum.into(%{})

    %{axon | output_weights: new_weights}
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0
end
