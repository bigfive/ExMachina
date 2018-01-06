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

  def get(:weight, %Neuron{axon: axon}, pid) do
    axon.output_weights[pid]
  end

  def get(:activity, %Neuron{dendrites: dendrites}) do
    dendrites.activity
  end

  def put(:target, %Neuron{} = neuron, target) do
    %{neuron | target: target}
  end

  def put(:activity, %Neuron{dendrites: dendrites, process_pid: process_pid} = neuron, activity, from) do
    dendrites = Dendrites.add_input_activity(activity, from, dendrites)
    if map_size(dendrites.input_activities) == dendrites.num_inputs, do: Process.fire(process_pid)

    %{neuron | dendrites: dendrites}
  end

  def fire(%Neuron{type: type} = neuron) do
    neuron
    |> (& apply(type, :compute_activity, [&1])).()
    |> (& apply(type, :send_forward_and_receive_errors, [&1])).()
    |> (& apply(type, :send_error_backward, [&1])).()
    |> (& apply(type, :adjust_weights, [&1])).()
  end

  defmacro __using__(_) do
    quote do
      alias Exmachina.Neuron
      alias Exmachina.Neuron.Dendrites
      alias Exmachina.Neuron.Axon

      def compute_activity(%Neuron{} = neuron) do
        neuron
      end

      def send_forward_and_receive_errors(%Neuron{} = neuron) do
        neuron
      end

      def send_error_backward(%Neuron{dendrites: dendrites} = neuron) do
        %{neuron | dendrites: Dendrites.reply_with(0, dendrites)}
      end

      def adjust_weights(%Neuron{} = neuron) do
        neuron
      end

      defoverridable [compute_activity: 1, send_forward_and_receive_errors: 1, send_error_backward: 1, adjust_weights: 1]
    end
  end
end
