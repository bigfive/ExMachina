defmodule Exmachina.Neuron.Process do
  alias Exmachina.Neuron
  use GenServer

  def start_link(num_inputs: num_inputs, output_pids: output_pids) do
    GenServer.start_link(__MODULE__, num_inputs: num_inputs, output_pids: output_pids)
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

  def init(num_inputs: num_inputs, output_pids: output_pids) do
    {:ok, Neuron.new(num_inputs: num_inputs, output_pids: output_pids, process_pid: self())}
  end

  def handle_call({:get_weight_for, output_pid}, _from, neuron) do
    weight = Neuron.get_weight_by_pid(neuron, output_pid)

    {:reply, weight, neuron}
  end

  def handle_call(:get_last_activity, _from, neuron) do
    activity = Neuron.get_activity(neuron)

    {:reply, activity, neuron}
  end

  def handle_call({:activate, activity}, from, neuron) do
    neuron = Neuron.record_activation(neuron, activity, from)

    {:noreply, neuron}
  end

  def handle_cast({:set_target, target}, neuron) do
    neuron = Neuron.record_new_target(neuron, target)

    {:noreply, neuron}
  end

  def handle_cast(:fire, neuron) do
    neuron = neuron
      |> Neuron.compute_activity
      |> Neuron.send_forward_and_receive_errors
      |> Neuron.send_error_backward
      |> Neuron.adjust_weights

    {:noreply, neuron}
  end
end
