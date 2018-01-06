defmodule Exmachina.Neuron.Process do
  alias Exmachina.Neuron
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def get_weight_for(pid, output_pid) do
    GenServer.call(pid, {:get_weight_for, output_pid})
  end

  def set_target(pid, target) do
    GenServer.cast(pid, {:set_target, target})
  end

  def get_last_activity(pid) do
    GenServer.call(pid, :get_last_activity)
  end

  def activate(pid, activity) do
    GenServer.call(pid, {:activate, activity})
  end

  def fire(pid) do
    GenServer.cast(pid, :fire)
  end

  def init(args) do
    neuron = Neuron.new(args ++ [process_pid: self()])

    {:ok, neuron}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %Neuron{} = neuron) do
    weight = Neuron.get(:weight, neuron, output_pid)

    {:reply, weight, neuron}
  end

  def handle_call(:get_last_activity, _from, %Neuron{} = neuron) do
    activity = Neuron.get(:activity, neuron)

    {:reply, activity, neuron}
  end

  def handle_call({:activate, activity}, from, %Neuron{} = neuron) do
    neuron = Neuron.put(:activity, neuron, activity, from)

    {:noreply, neuron}
  end

  def handle_cast({:set_target, target}, %Neuron{} = neuron) do
    neuron = Neuron.put(:target, neuron, target)

    {:noreply, neuron}
  end

  def handle_cast(:fire, %Neuron{} = neuron) do
    neuron = Neuron.fire(neuron)

    {:noreply, neuron}
  end
end
