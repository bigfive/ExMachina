defmodule Exmachina.Neuron.Dendrites do
  defstruct input_activities: %{}, num_inputs: nil, last_activity: nil, bias: nil, activity: nil

  def add_input_activity(%__MODULE__{input_activities: input_activities} = dendrites, activity, from) do
    %{dendrites | input_activities: Map.put(input_activities, from, activity)}
  end

  def compute_logistic_activity(%__MODULE__{bias: bias} = dendrites, inputs) do
    sum_activity = (inputs ++ [bias]) |> Enum.sum
    activity = Numerix.Special.logistic(sum_activity)
    %{dendrites | activity: activity}
  end

  def reply_with(%__MODULE__{input_activities: input_activities} = dendrites, reply) do
    Enum.all?(input_activities, fn {input_pid, _activity} ->
      :ok == GenServer.reply(input_pid, reply)
    end)
    %{dendrites | input_activities: %{}}
  end
end
