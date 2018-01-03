defmodule Exmachina.Network do
  alias Exmachina.Example
  alias Exmachina.Prediction
  alias Exmachina.Neuron
  alias Exmachina.OutputNeuron

  defstruct output_neurons: [], hidden_neurons: [], input_neurons: []

  def get_prediction_from_example(network, %Example{pixels: pixel_intensities, labels: label_values}) do
    set_labels(network, label_values)
    send_inputs(network, pixel_intensities)

    network
    |> get_outputs
    |> output_as_prediction(label_values)
  end

  defp set_labels(network, labels) do
    network.output_neurons
    |> Enum.zip(labels)
    |> Enum.each(fn ({output_neuron, label_value}) ->
      OutputNeuron.set_target(output_neuron, label_value)
    end)
  end

  defp send_inputs(network, input_intensities) do
    network.input_neurons
    |> Enum.zip(input_intensities)
    |> Task.async_stream(fn {neuron, intensity} -> Neuron.activate(neuron, intensity) end, max_concurrency: 999)
    |> Stream.run()
  end

  defp get_outputs(network) do
    network.output_neurons
    |> Enum.map(&OutputNeuron.get_last_activity/1)
  end

  defp output_as_prediction(outputs, labels) do
    input_number  = max_index(labels)
    output_number = max_index(outputs)
    was_correct   = case output_number do
      ^input_number -> 1
      _other_number -> 0
    end
    %Prediction{input_number: input_number, output_number: output_number, was_correct: was_correct}
  end

  defp max_index(outputs) do
    outputs
    |> Enum.with_index
    |> Enum.map(fn {output, index} -> {index, output} end)
    |> Enum.max_by(& elem(&1, 1))
    |> elem(0)
  end
end
