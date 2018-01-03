defmodule Exmachina.Neuron.Dendrites do
  alias Exmachina.Neuron
  @learning_rate 3.0

  defstruct output_weights: %{}, errors: %{}

  def output_activity(%__MODULE__{output_weights: output_weights} = dendrites, activity) do
    errors = output_weights
      |> Task.async_stream(fn {output_pid, weight} ->
        weighted_activity = calculate_weighted_activity(activity, weight)
        error = Neuron.activate(output_pid, weighted_activity)
        {output_pid, {error, weight}}
      end, max_concurrency: 999)
      |> Enum.map(fn {:ok, val} -> val end)
      |> Enum.into(%{})

    %{dendrites | errors: errors}
  end

  def adjust_weights(%__MODULE__{errors: errors} = dendrites, activity) do
    new_weights = errors
      |> Enum.map(fn {output_pid, {error, weight}} ->
        new_weight = weight - error * activity * @learning_rate
        {output_pid, new_weight}
      end)
      |> Enum.into(%{})

    %{dendrites | output_weights: new_weights}
  end

  # ---

  defp calculate_weighted_activity(activity, weight) do
    activity * weight
  end
end
