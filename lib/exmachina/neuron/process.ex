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
    {:ok, Neuron.new(args ++ [process_pid: self()])}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %Neuron{} = neuron) do
    weight = Neuron.get_weight_by_pid(neuron, output_pid)

    {:reply, weight, neuron}
  end

  def handle_call(:get_last_activity, _from, %Neuron{} = neuron) do
    activity = Neuron.get_activity(neuron)

    {:reply, activity, neuron}
  end

  def handle_call({:activate, activity}, from, %Neuron{} = neuron) do
    neuron = Neuron.record_activation(neuron, activity, from)

    {:noreply, neuron}
  end

  def handle_cast({:set_target, target}, %Neuron{} = neuron) do
    neuron = Neuron.record_new_target(neuron, target)

    {:noreply, neuron}
  end

  def handle_cast(:fire, %Neuron{type: type} = neuron) do
    neuron = neuron
      |> (& apply(type, :compute_activity, [&1])).()
      |> (& apply(type, :send_forward_and_receive_errors, [&1])).()
      |> (& apply(type, :send_error_backward, [&1])).()
      |> (& apply(type, :adjust_weights, [&1])).()

    {:noreply, neuron}
  end
end
