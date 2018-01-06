defmodule Exmachina.Neuron.Process do
  use GenServer

  def start_link(neuron_type: module, num_inputs: num_inputs, output_pids: output_pids) do
    GenServer.start_link(__MODULE__, neuron_type: module, num_inputs: num_inputs, output_pids: output_pids)
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

  def init(neuron_type: module, num_inputs: num_inputs, output_pids: output_pids) do
    {:ok, apply(module, :new, [[num_inputs: num_inputs, output_pids: output_pids, process_pid: self()]])}
  end

  def handle_call({:get_weight_for, output_pid}, _from, %module{} = neuron) do
    weight = apply(module, :get_weight_by_pid, [neuron, output_pid])

    {:reply, weight, neuron}
  end

  def handle_call(:get_last_activity, _from, %module{} = neuron) do
    activity = apply(module, :get_activity, [neuron])

    {:reply, activity, neuron}
  end

  def handle_call({:activate, activity}, from, %module{} = neuron) do
    neuron = apply(module, :record_activation, [neuron, activity, from])

    {:noreply, neuron}
  end

  def handle_cast({:set_target, target}, %module{} = neuron) do
    neuron = apply(module, :record_new_target, [neuron, target])

    {:noreply, neuron}
  end

  def handle_cast(:fire, %module{} = neuron) do
    neuron = neuron
      |> (& apply(module, :compute_activity, [&1])).()
      |> (& apply(module, :send_forward_and_receive_errors, [&1])).()
      |> (& apply(module, :send_error_backward, [&1])).()
      |> (& apply(module, :adjust_weights, [&1])).()

    {:noreply, neuron}
  end
end
