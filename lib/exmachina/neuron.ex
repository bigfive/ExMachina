defmodule Exmachina.Neuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Process
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  defstruct type: nil, dendrites: nil, axon: nil, process_pid: nil, target: nil

  defdelegate start_link(args),                to: Process
  defdelegate set_target(pid, output_pid),     to: Process
  defdelegate get_weight_for(pid, output_pid), to: Process
  defdelegate get_last_activity(pid),          to: Process
  defdelegate activate(pid, activity),         to: Process

  def new(type: type, num_inputs: num_inputs, output_pids: output_pids, process_pid: process_pid) do
    %Neuron{type: type, dendrites: Dendrites.new(num_inputs), axon: Axon.new(output_pids), process_pid: process_pid}
  end

  def record_new_target(%Neuron{} = neuron, target) do
    %{neuron | target: target}
  end

  def get_weight_by_pid(%Neuron{axon: axon}, pid) do
    axon.output_weights[pid]
  end

  def get_activity(%Neuron{dendrites: dendrites}) do
    dendrites.activity
  end

  def record_activation(%Neuron{dendrites: dendrites, process_pid: process_pid} = neuron, activity, from) do
    dendrites = Dendrites.add_input_activity(activity, from, dendrites)
    if map_size(dendrites.input_activities) == dendrites.num_inputs, do: Process.fire(process_pid)

    %{neuron | dendrites: dendrites}
  end
end
