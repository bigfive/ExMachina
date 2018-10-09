defmodule Exmachina do
  alias Exmachina.Network
  alias Exmachina.Example
  alias Exmachina.StatusWriter

  @num_output_units 10   # 1 unit for each label: "0" through "9"
  @num_hidden_units 8    # coz.. I like the number
  @num_input_units  256  # 1 unit for each pixel of the training cases

  @num_times_through_examples 20
  @dump_weights_every 20
  @print_summary_every 5

  def learn do
    # create the network
    network = Network.create_3_layer(@num_input_units, @num_hidden_units, @num_output_units)

    # load the examples
    examples = Example.load_examples()

    # build a status writer
    weights_file = File.open!("lib/output/weights.js", [:write])
    status_writer = %StatusWriter{
      network: network,
      weights_fn: &(IO.binwrite(weights_file,&1)),
      summary_fn: &(IO.write("                                 \r#{&1}")),
      weights_every: @dump_weights_every,
      summary_every: @print_summary_every,
    }

    # run through the training examples multiple times
    for run_index <- 1..@num_times_through_examples do
      examples
      |> Enum.shuffle()
      |> Enum.with_index()
      |> Enum.reduce(status_writer, fn ({example, example_index}, new_status_writer) ->
        network
        |> Network.get_prediction_and_learn_example(example)
        |> StatusWriter.add_prediction_and_write(new_status_writer, run: run_index, example: example_index)
      end)
    end

    network
  end
end
