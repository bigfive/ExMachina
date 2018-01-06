defmodule Exmachina.Neuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Process
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  @learning_rate 3.0

  defstruct dendrites: nil, axon: nil, process_pid: nil

  defdelegate start_link(args),                to: Process
  defdelegate get_weight_for(pid, output_pid), to: Process
  defdelegate activate(pid, activity),         to: Process

  def new(num_inputs: num_inputs, output_pids: output_pids, process_pid: process_pid) do
    %Neuron{dendrites: Dendrites.new(num_inputs), axon: Axon.new(output_pids), process_pid: process_pid}
  end

  def get_weight_by_pid(%Neuron{axon: axon}, pid) do
    Map.get(axon.output_weights, pid)
  end

  def record_activation(%Neuron{dendrites: dendrites, process_pid: process_pid} = neuron, activity, from) do
    dendrites = Dendrites.add_input_activity(activity, from, dendrites)
    if map_size(dendrites.input_activities) == dendrites.num_inputs, do: Process.fire(process_pid)

    %{neuron | dendrites: dendrites}
  end

  def compute_activity(%Neuron{dendrites: dendrites} = neuron) do
    dendrites = dendrites.input_activities
      |> Map.values()
      |> Dendrites.compute_logistic_activity(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def send_forward_and_receive_errors(%Neuron{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.output_weights
      |> Enum.map(fn {pid, weight} -> {pid, weight * dendrites.activity} end)
      |> Enum.into(%{})
      |> Axon.send_and_receive(axon)

    %{neuron | axon: axon}
  end

  def send_error_backward(%Neuron{axon: axon, dendrites: dendrites} = neuron) do
    dendrites = axon.responses
      |> Map.values
      |> Enum.zip(Map.values(axon.output_weights))
      |> Enum.map(fn {error, weight} -> error * weight end)
      |> Enum.sum()
      |> Kernel.*(dendrites.activity * (1 - dendrites.activity))
      |> Dendrites.reply_with(dendrites)

    %{neuron | dendrites: dendrites}
  end

  def adjust_weights(%Neuron{axon: axon, dendrites: dendrites} = neuron) do
    axon = axon.responses
      |> Enum.map(fn {pid, error} -> {pid, -(error * dendrites.activity * @learning_rate)} end)
      |> Enum.into(%{})
      |> Axon.adjust_weights(axon)

    %{neuron | axon: axon}
  end
end
