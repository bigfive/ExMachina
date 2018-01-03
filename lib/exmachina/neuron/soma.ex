defmodule Exmachina.Neuron.Soma do
  defstruct input_activities: %{}, num_inputs: nil, last_activity: nil, bias: nil, activity: nil

  def add_input_activity(%__MODULE__{input_activities: input_activities} = soma, activity, from) do
    %{soma | input_activities: Map.put(input_activities, from, activity)}
  end

  def compute_activity(%__MODULE__{input_activities: input_activities, bias: bias} = soma) do
    sum_activity = (Map.values(input_activities) ++ [bias]) |> Enum.sum
    activity = Numerix.Special.logistic(sum_activity)
    %{soma | activity: activity}
  end

  def reply_with_error(%__MODULE__{input_activities: input_activities, activity: activity} = soma, errors) do
    global_error = calculate_global_error(errors)
    input_error  = calculate_error_for_inputs(activity, global_error)

    Enum.all?(input_activities, fn {input_pid, _activity} ->
      :ok == GenServer.reply(input_pid, input_error)
    end)
    %{soma | input_activities: %{}}
  end

  # ---

  defp calculate_global_error(errors) do
    errors
    |> Enum.map(fn {_output_pid, {error, weight}} -> error * weight end)
    |> Enum.sum()
  end

  defp calculate_error_for_inputs(activity, global_error) do
    activity * (1 - activity) * global_error
  end
end
