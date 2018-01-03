defmodule Exmachina.Neuron.Axon do
  alias Exmachina.Neuron

  defstruct output_weights: %{}, responses: %{}

  def send_and_receive(%__MODULE__{} = axon, messages) do
    responses = messages
      |> Task.async_stream(fn {output_pid, message} ->
        response = Neuron.activate(output_pid, message)
        {output_pid, response}
      end, max_concurrency: 999)
      |> Enum.map(fn {:ok, val} -> val end)
      |> Enum.into(%{})

    %{axon | responses: responses}
  end

  def adjust_weights(%__MODULE__{output_weights: output_weights} = axon, adjustments) do
    new_weights = adjustments
      |> Enum.map(fn {output_pid, adjustment} ->
        old_weight = output_weights[output_pid]
        new_weight = old_weight + adjustment
        {output_pid, new_weight}
      end)
      |> Enum.into(%{})

    %{axon | output_weights: new_weights}
  end
end
