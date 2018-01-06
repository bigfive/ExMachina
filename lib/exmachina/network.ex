defmodule Exmachina.Network do
  alias Exmachina.Example
  alias Exmachina.Prediction
  alias Exmachina.Neuron
  alias Exmachina.OutputNeuron

  defstruct output_neurons: [], hidden_neurons: [], input_neurons: []

  def create_3_layer(num_inputs, num_hidden, num_outputs) do
    output_neurons = Enum.map(1..num_outputs, fn (_index) ->
      {:ok, pid} = OutputNeuron.start_link(num_inputs: num_hidden)
      pid
    end)

    hidden_neurons = Enum.map(1..num_hidden, fn (_index) ->
      {:ok, pid} = Neuron.start_link(num_inputs: num_inputs, output_pids: output_neurons)
      pid
    end)

    input_neurons = Enum.map(1..num_inputs, fn (_index) ->
      {:ok, pid} = Neuron.start_link(num_inputs: 1, output_pids: hidden_neurons)
      pid
    end)

    %__MODULE__{output_neurons: output_neurons, hidden_neurons: hidden_neurons, input_neurons: input_neurons}
  end

  def get_input_weights(network) do
    network.hidden_neurons
    |> Enum.map(fn (hidden_neuron) ->
      Enum.map(network.input_neurons, fn (input_neuron) ->
        Neuron.get_weight_for(input_neuron, hidden_neuron)
      end)
    end)
  end

  def get_output_weights(network) do
    network.output_neurons
    |> Enum.map(fn (output_neuron) ->
      Enum.map(network.hidden_neurons, fn (hidden_neuron) ->
        Neuron.get_weight_for(hidden_neuron, output_neuron)
      end)
    end)
  end

  def get_prediction_for_example(network, %Example{pixels: pixel_intensities, labels: label_values}) do
    network
    |> set_labels(label_values)
    |> send_inputs(pixel_intensities)
    |> get_outputs()
    |> output_as_prediction(label_values, pixel_intensities)
  end

  defp set_labels(network, labels) do
    network.output_neurons
    |> Enum.zip(labels)
    |> Enum.each(fn ({output_neuron, label_value}) ->
      OutputNeuron.set_target(output_neuron, label_value)
    end)
    network
  end

  defp send_inputs(network, input_intensities) do
    network.input_neurons
    |> Enum.zip(input_intensities)
    |> Task.async_stream(fn {neuron, intensity} -> Neuron.activate(neuron, intensity) end, max_concurrency: 999)
    |> Stream.run()
    network
  end

  defp get_outputs(network) do
    network.output_neurons
    |> Enum.map(&OutputNeuron.get_last_activity/1)
  end

  defp output_as_prediction(outputs, labels, pixels) do
    input_number  = max_index(labels)
    output_number = max_index(outputs)
    was_correct   = case output_number do
      ^input_number -> 1
      _other_number -> 0
    end
    %Prediction{input_number: input_number, output_number: output_number, was_correct: was_correct, pixels: pixels}
  end

  defp max_index(outputs) do
    outputs
    |> Enum.with_index
    |> Enum.map(fn {output, index} -> {index, output} end)
    |> Enum.max_by(& elem(&1, 1))
    |> elem(0)
  end
end
