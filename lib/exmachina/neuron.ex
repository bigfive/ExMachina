defmodule Exmachina.Neuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  use GenServer

  defstruct type: nil, dendrites: nil, axon: nil, target: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def get_weight_for(pid, output_pid) do
    GenServer.call(pid, {:get_weight_for, output_pid})
  end

  def get_last_activity(pid) do
    GenServer.call(pid, :get_last_activity)
  end

  def set_target(pid, target) do
    GenServer.cast(pid, {:set_target, target})
  end

  def activate(pid, activity) do
    GenServer.call(pid, {:activate, activity})
  end

  def fire(pid) do
    GenServer.cast(pid, :fire)
  end

  def init(type: type, num_inputs: num_inputs, output_pids: output_pids) do
    neuron = %Neuron{type: type, dendrites: Dendrites.new(num_inputs), axon: Axon.new(output_pids)}

    {:ok, neuron}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %Neuron{axon: axon} = neuron) do
    weight = axon.output_weights[output_pid]

    {:reply, weight, neuron}
  end

  def handle_call(:get_last_activity, _from, %Neuron{dendrites: dendrites} = neuron) do
    activity = dendrites.activity

    {:reply, activity, neuron}
  end

  def handle_call({:activate, activity}, from, %Neuron{dendrites: dendrites} = neuron) do
    dendrites = Dendrites.add_input_activity(activity, from, dendrites)
    if Dendrites.all_inputs_received?(dendrites), do: Neuron.fire(self())

    neuron = %{neuron | dendrites: dendrites}

    {:noreply, neuron}
  end

  def handle_cast({:set_target, target}, %Neuron{} = neuron) do
    neuron = %{neuron | target: target}

    {:noreply, neuron}
  end

  def handle_cast(:fire, %Neuron{type: type} = neuron) do
    %Neuron{} = neuron = apply(type, :fire, [neuron])

    {:noreply, neuron}
  end
end
