defmodule Exmachina.Neuron.OutputNeuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Dendrites

  def fire(%Neuron{} = neuron) do
    neuron
    |> compute_activity()
    |> send_error_backward()
  end

  defp compute_activity(%Neuron{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  defp send_error_backward(%Neuron{dendrites: dendrites, target: target} = neuron) do
    dendrites = -(target - dendrites.activity)
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end
end
