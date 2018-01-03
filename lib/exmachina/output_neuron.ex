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

defmodule Exmachina.OutputNeuron do
  use GenServer

  defmodule Data do
    defstruct input_activities: %{}, num_inputs: nil, target: nil, last_activity: nil, bias: nil
  end

  def start_link(num_inputs: num_inputs) do
    bias = init_weight() - 2.0
    GenServer.start_link(__MODULE__, %Data{num_inputs: num_inputs, bias: bias})
  end

  def set_target(pid, target), do: GenServer.call(pid, {:set_target, target})
  def get_last_activity(pid), do: GenServer.call(pid, :get)

  def handle_call(:get, _from, %Data{last_activity: last_activity} = state) do
    {:reply, last_activity, state}
  end

  def handle_call({:activate, activity}, from, state) do
    state = record_input_activity(activity, from, state)
    fire_if_all_received(state)

    {:noreply, state}
  end

  def handle_call({:set_target, target}, _from, state) do
    {:reply, :ok, %{state | target: target}}
  end

  def handle_cast(:fire, state) do
    with activity        <- compute_activity(state),
         global_error    <- calculate_global_error(activity, state.target),
         input_error     <- calculate_error_for_inputs(activity, global_error),
         true            <- send_back_to_inputs(input_error, state),
    do:  {:noreply, %{state | input_activities: %{}, last_activity: activity}}
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp record_input_activity(activity, from, %Data{input_activities: input_activities} = state) do
    %{state | input_activities: Map.put(input_activities, from, activity)}
  end

  defp fire_if_all_received(%Data{input_activities: input_activities, num_inputs: num_inputs}) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end

  defp compute_activity(%Data{input_activities: input_activities, bias: bias}) do
    sum_activity = (Map.values(input_activities) ++ [bias]) |> Enum.sum
    Numerix.Special.logistic(sum_activity)
  end

  defp calculate_global_error(activity, target) do
    -(target - activity)
  end

  defp calculate_error_for_inputs(activity, global_error) do
    activity * (1 - activity) * global_error
  end

  defp send_back_to_inputs(error_from_inputs, %Data{input_activities: input_activities}) do
    Enum.all?(input_activities, fn {input_pid, _activity} ->
      :ok == GenServer.reply(input_pid, error_from_inputs)
    end)
  end
end
