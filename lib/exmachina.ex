defmodule Exmachina do
  alias Exmachina.Network
  alias Exmachina.Example
  alias Exmachina.Prediction

  @num_output_units 10   # 1 unit for each label: "0" through "9"
  @num_hidden_units 14   # coz.. I like the number
  @num_input_units  256  # 1 unit for each pixel of the training cases

  @num_times_through_examples 15
  @dump_weights_every 50
  @print_status_every 10

  def learn do
    # create the network
    network = Network.create_3_layer(@num_input_units, @num_hidden_units, @num_output_units)

    # load the examples
    examples = Example.load_examples()

    # run through the training examples multiple times
    for run_through_index <- 1..@num_times_through_examples do
      Enum.reduce(examples, [], fn ({example, example_index}, predictions) ->

        # Get the prediction for this example (getting a prediction also 'learns' the example)
        prediction = Network.get_prediction_for_example(network, example)

        # Add it to the predictions accumulator
        predictions = [prediction | predictions] |> Enum.take(200)

        # sometimes dump the weights to a file
        if rem(example_index, @dump_weights_every) == 0, do: save_weights_to_file(network)

        # sometimes print a status update
        if rem(example_index, @print_status_every) == 0, do: print_status(predictions, run_through_index, example_index)

        # return the accumulator
        predictions

      end)
    end
    network
  end

  defp save_weights_to_file(network) do
    layer_1_json = network
      |> Network.get_input_weights()
      |> Poison.encode!()

    layer_2_json = network
      |> Network.get_output_weights()
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

    print_over "r:#{run_through_index} e:#{example_index} (#{percent_correct}% recently correct)"
  end

  defp print_over(string) do
    IO.write "                                 \r#{string}"
  end
end
