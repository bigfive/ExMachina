defmodule Exmachina.Neuron.LogisticNeuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  @learning_rate 2.0

  def fire(%Neuron{} = neuron) do
    neuron
    |> compute_activity()
    |> send_forward_and_receive_errors()
    |> send_error_backward()
    |> adjust_weights()
  end

  defp compute_activity(%Neuron{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  defp send_forward_and_receive_errors(%Neuron{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.output_weights
      |> Enum.map(fn {pid, weight} -> {pid, weight * dendrites.activity} end)
      |> Enum.into(%{})
      |> Axon.send_and_receive(axon)

    %{neuron | axon: axon}
  end

  defp send_error_backward(%Neuron{axon: axon, dendrites: dendrites, target: nil} = neuron) do
    dendrites = axon.responses
      |> Map.values
      |> Enum.zip(Map.values(axon.output_weights))
      |> Enum.map(fn {error, weight} -> error * weight end)
      |> Enum.sum()
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end

  defp adjust_weights(%Neuron{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.responses
      |> Enum.map(fn {pid, error} -> {pid, -(error * dendrites.activity * @learning_rate)} end)
      |> Enum.into(%{})
      |> Axon.adjust_weights(axon)

    %{neuron | axon: axon}
  end
end
