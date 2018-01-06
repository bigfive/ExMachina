defmodule Exmachina.Neuron.OutputNeuron do
  use Exmachina.Neuron

  def compute_activity(%Neuron{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def send_error_backward(%Neuron{dendrites: dendrites, target: target} = neuron) do
    dendrites = -(target - dendrites.activity)
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end
end
