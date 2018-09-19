defmodule Exmachina.Neuron.Axon do
  alias Exmachina.Neuron.Axon
  alias Exmachina.Neuron

  defstruct output_weights: %{}, responses: %{}

  def new([]), do: %Axon{}
  def new(output_pids) do
    output_weights = output_pids
      |> Enum.map(& {&1, init_weight()})
      |> Enum.into(%{})

    %Axon{output_weights: output_weights}
  end

  def send_and_receive(messages, %Axon{} = axon) do
    responses = axon
      |> with_each_output(fn (output_pid) ->
        message = messages[output_pid]
        response = Neuron.activate(output_pid, message)
        {output_pid, response}
      end)
      |> Enum.into(%{})

    %{axon | responses: responses}
  end

  def adjust_weights(adjustments, %Axon{output_weights: output_weights} = axon) do
    new_weights = axon
      |> with_each_output(fn (output_pid) ->
        adjustment = adjustments[output_pid]
        old_weight = output_weights[output_pid]
        new_weight = old_weight + adjustment
        {output_pid, new_weight}
      end)
      |> Enum.into(%{})

    %{axon | output_weights: new_weights}
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp with_each_output(%Axon{output_weights: output_weights}, function) do
    output_weights
    |> Map.keys()
    |> Task.async_stream(function, max_concurrency: map_size(output_weights))
    |> Enum.map(fn {:ok, val} -> val end)
  end
end
