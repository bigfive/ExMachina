defmodule Exmachina.LogisticNeuron do
  use Exmachina.Neuron

  @learning_rate 3.0

  def compute_activity(%__MODULE__{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def send_forward_and_receive_errors(%__MODULE__{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.output_weights
      |> Enum.map(fn {pid, weight} -> {pid, weight * dendrites.activity} end)
      |> Enum.into(%{})
      |> Axon.send_and_receive(axon)

    %{neuron | axon: axon}
  end

  def send_error_backward(%__MODULE__{axon: axon, dendrites: dendrites, target: nil} = neuron) do
    dendrites = axon.responses
      |> Map.values
      |> Enum.zip(Map.values(axon.output_weights))
      |> Enum.map(fn {error, weight} -> error * weight end)
      |> Enum.sum()
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def adjust_weights(%__MODULE__{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.responses
      |> Enum.map(fn {pid, error} -> {pid, -(error * dendrites.activity * @learning_rate)} end)
      |> Enum.into(%{})
      |> Axon.adjust_weights(axon)

    %{neuron | axon: axon}
  end
end
