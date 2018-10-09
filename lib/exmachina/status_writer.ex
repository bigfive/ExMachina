defmodule Exmachina.StatusWriter do
  alias Exmachina.Prediction
  alias Exmachina.Network

  defstruct network: nil, weights_fn: nil, summary_fn: nil, weights_every: nil, summary_every: nil, predictions: []

  def add_prediction_and_write(prediction, writer, run: run, example: example) do
    with(
      new_predictions <- recent_predictions(writer, prediction),
      :ok             <- write_weights(writer, new_predictions, example),
      :ok             <- write_summary(writer, new_predictions, run, example)
    ) do
      %{writer | predictions: new_predictions}
    end
  end

  defp recent_predictions(%{predictions: predictions}, prediction) do
    [prediction | predictions] |> Enum.take(200)
  end

  defp write_weights(%{weights_every: weights_every}, _new_predictions, example) when rem(example, weights_every) != 0, do: :ok
  defp write_weights(%{weights_fn: weights_fn, network: network}, new_predictions, _example) do
    layer_1_json = network
      |> Network.get_input_weights()
      |> Poison.encode!()

    layer_2_json = network
      |> Network.get_output_weights()
      |> Poison.encode!()

    prediction_json = new_predictions
      |> Enum.take(10)
      |> Poison.encode!()

    weights_fn.("
      document.layer1Weights = #{layer_1_json};
      document.layer2Weights = #{layer_2_json};
      document.predictions   = #{prediction_json};
    ")
  end

  defp write_summary(%{summary_every: summary_every}, _new_predictions, _run, example) when rem(example, summary_every) != 0, do: :ok
  defp write_summary(%{summary_fn: summary_fn}, new_predictions, run, example) do
    number_correct = new_predictions
      |> Enum.map(fn %Prediction{was_correct: true} -> 1; %Prediction{was_correct: false} -> 0 end)
      |> Enum.sum()

    fraction_correct = number_correct / length(new_predictions)
    percent_correct = Float.round(fraction_correct * 100.0, 3)

    summary_fn.("r:#{run} e:#{example} (#{percent_correct}% recently correct)")
  end
end
