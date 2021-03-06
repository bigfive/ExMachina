defmodule Exmachina.Neuron.Dendrites do
  alias Exmachina.Neuron.Dendrites

  defstruct input_activities: %{}, num_inputs: nil, bias: nil, activity: nil

  def new(num_inputs) do
    %Dendrites{num_inputs: num_inputs, bias: init_bias() }
  end

  def add_input_activity(activity, from, %Dendrites{input_activities: input_activities} = dendrites) do
    %{dendrites | input_activities: Map.put(input_activities, from, activity)}
  end

  def all_inputs_received?(%Dendrites{input_activities: input_activities, num_inputs: num_inputs}) do
    map_size(input_activities) == num_inputs
  end

  def compute_logistic_activity(inputs, %Dendrites{bias: bias} = dendrites) do
    sum_activity = (inputs ++ [bias]) |> Enum.sum
    activity = Numerix.Special.logistic(sum_activity)
    %{dendrites | activity: activity}
  end

  def reply_with(reply, %Dendrites{} = dendrites) do
    dendrites
    |> with_each_input(fn input -> :ok = GenServer.reply(input, reply) end)

    %{dendrites | input_activities: %{}}
  end

  defp init_bias, do: (:rand.uniform() * 2) - 3.0

  defp with_each_input(%Dendrites{input_activities: input_activities}, function) do
    input_activities
    |> Map.keys()
    |> Task.async_stream(function, max_concurrency: map_size(input_activities))
    |> Enum.map(fn {:ok, val} -> val end)
  end
end
