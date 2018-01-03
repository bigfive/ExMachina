defmodule Exmachina.Neuron do
  alias Exmachina.Neuron.Soma
  alias Exmachina.Neuron.Dendrites

  use GenServer

  defstruct soma: nil, dendrites: nil

  def start_link(num_inputs: num_inputs, output_pids: output_pids) do
    bias = init_weight() - 2.0
    soma = %Soma{num_inputs: num_inputs, bias: bias}

    output_weights = output_pids |> Enum.map(& {&1, init_weight()}) |> Enum.into(%{})
    dendrites = %Dendrites{output_weights: output_weights}

    GenServer.start_link(__MODULE__, %__MODULE__{soma: soma, dendrites: dendrites})
  end

  def activate(pid, activity) do
    GenServer.call(pid, {:activate, activity})
  end

  def get_weight_for(pid, output_pid) do
    GenServer.call(pid, {:get_weight_for, output_pid})
  end

  def handle_call({:activate, activity}, from, %__MODULE__{soma: soma} = state) do
    soma = Soma.add_input_activity(soma, activity, from)
    fire_if_all_received(soma.input_activities, soma.num_inputs)

    {:noreply, %{state | soma: soma}}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %__MODULE__{dendrites: dendrites} = state) do
    weight = Map.get(dendrites.output_weights, output_pid)

    {:reply, weight, state}
  end

  def handle_cast(:fire, %__MODULE__{soma: soma, dendrites: dendrites} = state) do
    with(
      soma        <- Soma.compute_activity(soma),
      dendrites   <- Dendrites.output_activity(dendrites, soma.activity),
      soma        <- Soma.reply_with_error(soma, dendrites.errors),
      dendrites   <- Dendrites.adjust_weights(dendrites, soma.activity)
    ) do
      {:noreply, %{state | soma: soma, dendrites: dendrites}}
    end
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp fire_if_all_received(input_activities, num_inputs) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end
end
