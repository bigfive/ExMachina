defmodule Exmachina do
  @num_output_units 10   # 1 unit for each label: "0" through "9"
  @num_hidden_units 6    # coz.. I like the number
  @num_input_units  256  # 1 unit for each pixel of the training cases

  def test do
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

    # run through the training examples 1000 times each
    for run_through_index <- 1..1000 do
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

        # print the input weights of the first hidden neuron
        if rem(example_index, 100) == 0 do
          input_neurons
          |> Enum.map(& Exmachina.Neuron.get_weight_for(&1, List.last(hidden_neurons)))
          |> print_square_image
        end

        # Get result
        output_values = Enum.map(output_neurons, &Exmachina.OutputNeuron.get_last_activity/1)

        input_number  = max_index(label_values)
        output_number = max_index(output_values)

        # Add answer to accumulator
        answers = output_number
          |> case do
            ^input_number -> [1 | answers]
            _other_number -> [0 | answers]
          end
          |> Enum.take(200)

        # sometimes print a status update
        if rem(example_index, 10) == 0 do
          fraction_correct = Enum.sum(answers) / length(answers)
          print_over "r:#{run_through_index} e:#{example_index} (#{Float.round(fraction_correct * 100.0, 3)}% recently correct)"
        end

        answers
      end)
    end

    IO.puts ""
    :ok
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

  defp print_square_image(pixels) do
    num_pixels = length(pixels)
    width = round(:math.sqrt(num_pixels))

    IO.puts ""
    pixels
    |> Enum.chunk_every(width)
    |> Enum.each(fn line ->
      line
      |> Enum.map(& :erlang.float_to_binary(&1, decimals: 2))
      |> Enum.map(& String.pad_leading(&1, 4, " "))
      |> Enum.join(" | ")
      |> IO.puts
    end)
  end

  defp shade(float) when float <= 0.2, do: " "
  defp shade(float) when float <= 0.4, do: "░"
  defp shade(float) when float <= 0.6, do: "▒"
  defp shade(float) when float <= 0.8, do: "▓"
  defp shade(float) when float >  0.8, do: "▮"
end
