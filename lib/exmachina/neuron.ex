### RUN SHEET OF A NEURON
#
# 1) Wait for all inputs to send activities (remember these connections)
# 2) Compute activity
# 3) Compute weighted activities
# 4) Send to weighted activities to outputs
# 5) Wait for all output responses. (IE the dE/dz of each connected output neuron)
# 6) Compute dE/dz (via dE/dy)
# 7) Send dE/dz back to open connections from step 1
# 8) Compute dE/dw
# 9) Update weights

# https://www.youtube.com/watch?v=Z8jzCvb62e8&list=PLoRl3Ht4JOcdU872GhiYWf6jwrk_SNhz9&index=13

defmodule Exmachina.Neuron do
  use GenServer

  @e :math.exp(1)
  @learning_rate 0.2

  defmodule Data do
    defstruct input_activities: %{}, num_inputs: nil, outputs: %{}, bias: nil
  end

  def start_link(num_inputs: num_inputs, output_pids: output_pids) do
    outputs = output_pids
      |> Enum.map(& {&1, init_weight()})
      |> Enum.into(%{})

    bias = init_weight()

    GenServer.start_link(__MODULE__, %Data{num_inputs: num_inputs, outputs: outputs, bias: bias})
  end

  def activate(pid, activity), do: GenServer.call(pid, {:activate, activity})
  def get_weight_for(pid, output_pid), do: GenServer.call(pid, {:get_weight_for, output_pid})

  def handle_call({:activate, activity}, from, state) do
    state = record_input_activity(activity, from, state)
    fire_if_all_received(state)

    {:noreply, state}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %Data{outputs: outputs} = state) do
    {:reply, Map.get(outputs, output_pid), state}
  end

  def handle_cast(:fire, state) do
    with activity        <- compute_activity(state),
         outgoing_errors <- send_activity_to_outputs(activity, state),
         input_error     <- calculate_input_error(activity, outgoing_errors, state),
         true            <- send_back_to_inputs(input_error, state),
         new_weights     <- get_new_weight_map(outgoing_errors, activity, state),
    do:  {:noreply, %{state | input_activities: %{}, outputs: new_weights}}
  end

  defp init_weight, do: :rand.uniform() - 0.5

  defp record_input_activity(activity, from, %Data{input_activities: input_activities} = state) do
    %{state | input_activities: Map.put(input_activities, from, activity)}
  end

  defp fire_if_all_received(%Data{input_activities: input_activities, num_inputs: num_inputs}) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end

  defp compute_activity(%Data{input_activities: input_activities, bias: bias}) do
    sum_activity = (Map.values(input_activities) ++ [bias]) |> Enum.sum
    # (1 / (1 + :math.pow(@e, -sum_activity)))
    Numerix.Special.logistic(sum_activity)
  end

  defp send_activity_to_outputs(activity, %Data{outputs: outputs}) do
    Enum.map(outputs, fn {output_pid, weight} ->
      weighted_activity = calculate_weighted_activity(activity, weight)
      delta = Exmachina.Neuron.activate(output_pid, weighted_activity)
      {output_pid, delta}
    end)
    |> Enum.into(%{})
  end

  defp calculate_input_error(activity, outgoing_errors, %Data{outputs: outputs}) do
    overral_delta = outputs
      |> Enum.map(fn {output_pid, weight} -> Map.get(outgoing_errors, output_pid) * weight end)
      |> Enum.sum()

    activity * (1 - activity) * overral_delta
  end

  defp send_back_to_inputs(input_error, %Data{input_activities: input_activities}) do
    Enum.all?(input_activities, fn {input_pid, _activity} ->
      :ok = GenServer.reply(input_pid, input_error)
    end)
  end

  defp get_new_weight_map(outgoing_errors, activity, %Data{outputs: outputs}) do
    Enum.map(outputs, fn {output_pid, weight} ->
      {output_pid, weight + Map.get(outgoing_errors, output_pid) * activity * @learning_rate}
    end)
    |> Enum.into(%{})
  end

  defp calculate_weighted_activity(activity, weight) do
    activity * weight
  end
end
