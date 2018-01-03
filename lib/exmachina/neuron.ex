defmodule Exmachina.Neuron do
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  use GenServer

  defstruct dendrites: nil, axon: nil

  def start_link(num_inputs: num_inputs, output_pids: output_pids) do
    bias = init_weight() - 2.0
    dendrites = %Dendrites{num_inputs: num_inputs, bias: bias}

    output_weights = output_pids |> Enum.map(& {&1, init_weight()}) |> Enum.into(%{})
    axon = %Axon{output_weights: output_weights}

    GenServer.start_link(__MODULE__, %__MODULE__{dendrites: dendrites, axon: axon})
  end

  def activate(pid, activity) do
    GenServer.call(pid, {:activate, activity})
  end

  def get_weight_for(pid, output_pid) do
    GenServer.call(pid, {:get_weight_for, output_pid})
  end

  def handle_call({:activate, activity}, from, %__MODULE__{dendrites: dendrites} = state) do
    dendrites = Dendrites.add_input_activity(dendrites, activity, from)
    fire_if_all_received(dendrites.input_activities, dendrites.num_inputs)

    {:noreply, %{state | dendrites: dendrites}}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %__MODULE__{axon: axon} = state) do
    weight = Map.get(axon.output_weights, output_pid)

    {:reply, weight, state}
  end

  def handle_cast(:fire, %__MODULE__{dendrites: dendrites, axon: axon} = state) do
    with(
      dendrites <- Dendrites.compute_activity(dendrites),
      axon      <- Axon.output_activity(axon, dendrites.activity),
      dendrites <- Dendrites.reply_with_error(dendrites, axon.errors),
      axon      <- Axon.adjust_weights(axon, dendrites.activity)
    ) do
      {:noreply, %{state | dendrites: dendrites, axon: axon}}
    end
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp fire_if_all_received(input_activities, num_inputs) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end
end
