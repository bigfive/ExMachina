defmodule Exmachina do
  @num_output_units 10   # 1 unit for each label: "0" through "9"
  @num_hidden_units 14    # coz.. I like the number
  @num_input_units  256  # 1 unit for each pixel of the training cases

  @num_times_through_examples 15
  @dump_weights_every 50
  @print_status_every 10

  defmodule Example do
    defstruct pixels: [], labels: []

    def load_examples do
      "lib/examples/semeion.data"
      |> File.stream!()
      |> Enum.map(fn line ->
        row = line |> String.trim("\n") |> String.split(" ")
        pixels = Enum.take(row, 256) |> Enum.map(&String.to_float/1)
        labels = Enum.take(row, -10) |> Enum.map(&String.to_integer/1)

        %__MODULE__{pixels: pixels, labels: labels}
      end)
      |> Enum.shuffle
      |> Enum.with_index
    end

    def load_random_example() do
      load_examples()
      |> List.first
      |> elem(0)
    end
  end

  defmodule Prediction do
    defstruct input_number: nil, output_number: nil, was_correct: nil
  end

  defmodule Network do
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
        Exmachina.OutputNeuron.set_target(output_neuron, label_value)
      end)
    end

    defp send_inputs(network, input_intensities) do
      network.input_neurons
      |> Enum.zip(input_intensities)
      |> Task.async_stream(fn {neuron, intensity} -> Exmachina.Neuron.activate(neuron, intensity) end, max_concurrency: 999)
      |> Stream.run()
    end

    defp get_outputs(network) do
      network.output_neurons
      |> Enum.map(&Exmachina.OutputNeuron.get_last_activity/1)
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

  def learn do
    # output units
    output_neurons = Enum.map(1..@num_output_units, fn (_index) ->
      {:ok, pid} = Exmachina.OutputNeuron.start_link(num_inputs: @num_hidden_units)
      pid
    end)

    # hidden units
    hidden_neurons = Enum.map(1..@num_hidden_units, fn (_index) ->
      {:ok, pid} = Exmachina.Neuron.start_link(num_inputs: @num_input_units, output_pids: output_neurons)
      pid
    end)

    # input units
    input_neurons = Enum.map(1..@num_input_units, fn (_index) ->
      {:ok, pid} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: hidden_neurons)
      pid
    end)

    network = %Network{output_neurons: output_neurons, hidden_neurons: hidden_neurons, input_neurons: input_neurons}

    # load the examples
    examples = Example.load_examples()

    # run through the training examples multiple times
    for run_through_index <- 1..@num_times_through_examples do
      examples
      |> Enum.reduce([], fn ({example, example_index}, predictions) ->
        prediction = Network.get_prediction_from_example(network, example)
        predictions = [prediction | predictions] |> Enum.take(200)

        # sometimes dump the weights to a file
        if rem(example_index, @dump_weights_every) == 0, do: save_weights_to_file(network)

        # sometimes print a status update
        if rem(example_index, @print_status_every) == 0, do: print_status(predictions, run_through_index, example_index)

        predictions
      end)
    end
    network
  end

  defp save_weights_to_file(network) do
    layer_1_json = network.hidden_neurons
      |> Enum.map(fn (hidden_neuron) ->
        Enum.map(network.input_neurons, fn (input_neuron) ->
          Exmachina.Neuron.get_weight_for(input_neuron, hidden_neuron)
        end)
      end)
      |> Poison.encode!()

    layer_2_json = network.output_neurons
      |> Enum.map(fn (output_neuron) ->
        Enum.map(network.hidden_neurons, fn (hidden_neuron) ->
          Exmachina.Neuron.get_weight_for(hidden_neuron, output_neuron)
        end)
      end)
      |> Poison.encode!()


    {:ok, file} = File.open("lib/output/weights.js", [:write])
    :ok = IO.binwrite file, "document.layer1Weights = #{layer_1_json}; document.layer2Weights = #{layer_2_json};"
    :ok = File.close file
  end

  defp print_status(predictions, run_through_index, example_index) do
    number_correct = predictions
      |> Enum.map(fn %Prediction{was_correct: correct} -> correct end)
      |> Enum.sum()

    fraction_correct = number_correct / length(predictions)
    percent_correct = Float.round(fraction_correct * 100.0, 3)

    recent_predictions = predictions
      |> Enum.take(5)
      |> Enum.map(fn %Prediction{output_number: number} -> number end)
      |> Enum.join(",")

    print_over "r:#{run_through_index} e:#{example_index} (#{percent_correct}% recently correct) -- #{recent_predictions}"
  end

  defp print_over(string) do
    IO.write "                                 \r#{string}"
  end
end
