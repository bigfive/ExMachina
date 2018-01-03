defmodule Exmachina.OutputNeuron do
  alias Exmachina.Neuron.Dendrites

  use GenServer

  defstruct dendrites: nil, target: nil

  def start_link(num_inputs: num_inputs) do
    bias = init_weight() - 2.0
    dendrites = %Dendrites{num_inputs: num_inputs, bias: bias}

    GenServer.start_link(__MODULE__, %__MODULE__{dendrites: dendrites})
  end

  def set_target(pid, target) do
    GenServer.call(pid, {:set_target, target})
  end

  def get_last_activity(pid) do
    GenServer.call(pid, :get_last_activity)
  end

  def handle_call({:activate, activity}, from, %__MODULE__{dendrites: dendrites} = state) do
    dendrites = Dendrites.add_input_activity(dendrites, activity, from)
    fire_if_all_received(dendrites.input_activities, dendrites.num_inputs)

    {:noreply, %{state | dendrites: dendrites}}
  end

  def handle_call({:set_target, target}, _from, state) do
    {:reply, :ok, %{state | target: target}}
  end

  def handle_call(:get_last_activity, _from, %__MODULE__{dendrites: dendrites} = state) do
    {:reply, dendrites.activity, state}
  end

  def handle_cast(:fire, %__MODULE__{dendrites: dendrites, target: target} = state) do
    with(
      dendrites  <- Dendrites.compute_activity(dendrites),
      error      <- mimic_error_response(dendrites.activity, target),
      dendrites  <- Dendrites.reply_with_error(dendrites, error)
    ) do
      {:noreply, %{state | dendrites: dendrites}}
    end
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp fire_if_all_received(input_activities, num_inputs) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end

  defp mimic_error_response(activity, target) do
    weight = 1
    error = -(target - activity)
    %{self() => {error, weight}}
  end
end
