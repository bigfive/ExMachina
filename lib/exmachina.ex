defmodule Exmachina do
  @num_output_units 10   # 1 unit for each label: "0" through "9"
  @num_hidden_units 12    # coz.. I like the number
  @num_input_units  256  # 1 unit for each pixel of the training cases

  defmodule Network do
    defstruct output_neurons: [], hidden_neurons: [], input_neurons: []
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

    # load the examples
    examples = get_examples()

    # run through the training examples 10 times each
    for run_through_index <- 1..10 do
      examples
      |> Enum.reduce([], fn ({%{pixels: pixel_intensities, labels: label_values}, example_index}, answers) ->

        # set labels
        Enum.zip(output_neurons, label_values)
        |> Enum.each(fn ({output_neuron, label_value}) ->
          Exmachina.OutputNeuron.set_target(output_neuron, label_value)
        end)

        # send input activity
        Enum.zip(input_neurons, pixel_intensities)
        |> Task.async_stream(fn {neuron, intensity} -> Exmachina.Neuron.activate(neuron, intensity) end, max_concurrency: 999)
        |> Stream.run()

        # sometimes dump the weights to a file
        if rem(example_index, 100) == 0 do
          layer_1_json = hidden_neurons
            |> Enum.map(fn (hidden_neuron) ->
              Enum.map(input_neurons, fn (input_neuron) ->
                Exmachina.Neuron.get_weight_for(input_neuron, hidden_neuron)
              end)
            end)
            |> Poison.encode!()

          layer_2_json = output_neurons
            |> Enum.map(fn (output_neuron) ->
              Enum.map(hidden_neurons, fn (hidden_neuron) ->
                Exmachina.Neuron.get_weight_for(hidden_neuron, output_neuron)
              end)
            end)
            |> Poison.encode!()


          {:ok, file} = File.open("lib/output/weights.js", [:write])
          :ok = IO.binwrite file, "document.layer1Weights = #{layer_1_json}; document.layer2Weights = #{layer_2_json};"
          :ok = File.close file
        end

        # Get activities
        output_values = Enum.map(output_neurons, &Exmachina.OutputNeuron.get_last_activity/1)

        # Get result
        input_number  = max_index(label_values)
        output_number = max_index(output_values)
        correct = case output_number do
          ^input_number -> 1
          _other_number -> 0
        end

        # Add answer to accumulator
        answers = [{input_number, output_number, correct} | answers] |> Enum.take(200)

        # sometimes print a status update
        if rem(example_index, 10) == 0 do
          fraction_correct = (answers |> Enum.map(& elem(&1, 2)) |> Enum.sum) / length(answers)
          print_over "r:#{run_through_index} e:#{example_index} (#{Float.round(fraction_correct * 100.0, 3)}% recently correct) -- #{answers |> Enum.take(5) |> Enum.map(& elem(&1, 1)) |> Enum.join(",")}"
        end

        answers
      end)
    end

    IO.puts ""

    %Network{output_neurons: output_neurons, hidden_neurons: hidden_neurons, input_neurons: input_neurons}
  end

  def get_random_example() do
    get_examples() |> List.first |> elem(1)
  end

  defp get_examples() do
    "lib/examples/semeion.data"
    |> File.stream!()
    |> Enum.map(fn line ->
      row = line |> String.trim("\n") |> String.split(" ")
      pixels = Enum.take(row, 256) |> Enum.map(&String.to_float/1)
      labels = Enum.take(row, -10) |> Enum.map(&String.to_integer/1)

      %{pixels: pixels, labels: labels}
    end)
    |> Enum.shuffle
    |> Enum.with_index
  end

  defp max_index(outputs) do
    outputs
    |> Enum.with_index
    |> Enum.map(fn {output, index} -> {index, output} end)
    |> Enum.max_by(& elem(&1, 1))
    |> elem(0)
  end

  defp print_over(string) do
    IO.write "                                 \r#{string}"
  end
end
