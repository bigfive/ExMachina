defmodule Exmachina.Neuron.Dendrites do
  defstruct input_activities: %{}, num_inputs: nil, bias: nil, activity: nil

  def new(num_inputs) do
    %__MODULE__{num_inputs: num_inputs, bias: init_weight() }
  end

  def add_input_activity(activity, from, %__MODULE__{input_activities: input_activities} = dendrites) do
    %{dendrites | input_activities: Map.put(input_activities, from, activity)}
  end

  def compute_logistic_activity(inputs, %__MODULE__{bias: bias} = dendrites) do
    sum_activity = (inputs ++ [bias]) |> Enum.sum
    activity = Numerix.Special.logistic(sum_activity)
    %{dendrites | activity: activity}
  end

  def reply_with(reply, %__MODULE__{input_activities: input_activities} = dendrites) do
    Enum.all?(input_activities, fn {input_pid, _activity} ->
      :ok == GenServer.reply(input_pid, reply)
    end)
    %{dendrites | input_activities: %{}}
  end

  defp init_weight, do: (:rand.uniform() * 2) - 3.0
end
