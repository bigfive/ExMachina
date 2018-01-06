defmodule Exmachina.OutputNeuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Dendrites

  def compute_activity(%Neuron{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def send_forward_and_receive_errors(neuron), do: neuron

  def send_error_backward(%Neuron{dendrites: dendrites, target: target} = neuron) do
    dendrites = -(target - dendrites.activity)
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def adjust_weights(neuron), do: neuron
end
