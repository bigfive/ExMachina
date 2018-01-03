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

  defstruct soma: nil, dendrites: nil

  defmodule Soma do
    defstruct input_activities: %{}, num_inputs: nil, last_activity: nil, bias: nil, activity: nil

    def add_input_activity(%Soma{input_activities: input_activities} = soma, activity, from) do
      %{soma | input_activities: Map.put(input_activities, from, activity)}
    end

    def compute_activity(%Soma{input_activities: input_activities, bias: bias} = soma) do
      sum_activity = (Map.values(input_activities) ++ [bias]) |> Enum.sum
      activity = Numerix.Special.logistic(sum_activity)
      %{soma | activity: activity}
    end

    def reply_with_error(%Soma{input_activities: input_activities, activity: activity} = soma, errors) do
      global_error = calculate_global_error(errors)
      input_error  = calculate_error_for_inputs(activity, global_error)

      Enum.all?(input_activities, fn {input_pid, _activity} ->
        :ok == GenServer.reply(input_pid, input_error)
      end)
      %{soma | input_activities: %{}}
    end

    defp calculate_global_error(errors) do
      errors
      |> Enum.map(fn {_output_pid, {error, weight}} -> error * weight end)
      |> Enum.sum()
    end

    defp calculate_error_for_inputs(activity, global_error) do
      activity * (1 - activity) * global_error
    end
  end

  defmodule Dendrites do
    @learning_rate 3.0

    defstruct output_weights: %{}, errors: %{}

    def output_activity(%Dendrites{output_weights: output_weights} = dendrites, activity) do
      errors = output_weights
        |> Task.async_stream(fn {output_pid, weight} ->
          weighted_activity = calculate_weighted_activity(activity, weight)
          error = Exmachina.Neuron.activate(output_pid, weighted_activity)
          {output_pid, {error, weight}}
        end, max_concurrency: 999)
        |> Enum.map(fn {:ok, val} -> val end)
        |> Enum.into(%{})

      %{dendrites | errors: errors}
    end

    def adjust_weights(%Dendrites{errors: errors} = dendrites, activity) do
      new_weights = errors
        |> Enum.map(fn {output_pid, {error, weight}} ->
          new_weight = weight - error * activity * @learning_rate
          {output_pid, new_weight}
        end)
        |> Enum.into(%{})

      %{dendrites | output_weights: new_weights}
    end

    defp calculate_weighted_activity(activity, weight) do
      activity * weight
    end
  end

  def start_link(num_inputs: num_inputs, output_pids: output_pids) do
    bias = init_weight() - 2.0
    soma = %Soma{num_inputs: num_inputs, bias: bias}

    output_weights = output_pids |> Enum.map(& {&1, init_weight()}) |> Enum.into(%{})
    dendrites = %Dendrites{output_weights: output_weights}

    GenServer.start_link(__MODULE__, %__MODULE__{soma: soma, dendrites: dendrites})
  end

  def activate(pid, activity), do: GenServer.call(pid, {:activate, activity})
  def get_weight_for(pid, output_pid), do: GenServer.call(pid, {:get_weight_for, output_pid})

  def handle_call({:activate, activity}, from, %__MODULE__{soma: soma} = state) do
    soma = Soma.add_input_activity(soma, activity, from)
    fire_if_all_received(soma.input_activities, soma.num_inputs)

    {:noreply, %{state | soma: soma}}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %__MODULE__{dendrites: dendrites} = state) do
    {:reply, Map.get(dendrites.output_weights, output_pid), state}
  end

  def handle_cast(:fire, %__MODULE__{dendrites: dendrites, soma: soma} = state) do
    with soma        <- Soma.compute_activity(soma),
         dendrites   <- Dendrites.output_activity(dendrites, soma.activity),
         soma        <- Soma.reply_with_error(soma, dendrites.errors),
         dendrites   <- Dendrites.adjust_weights(dendrites, soma.activity),
    do:  {:noreply, %{state | soma: soma, dendrites: dendrites}}
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp fire_if_all_received(input_activities, num_inputs) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end
end
