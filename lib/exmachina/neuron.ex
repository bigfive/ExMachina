defmodule Exmachina.Neuron do
  alias Exmachina.Neuron
  alias Exmachina.Neuron.Process
  alias Exmachina.Neuron.Dendrites
  alias Exmachina.Neuron.Axon

  # @learning_rate 3.0

  defmacro __using__(_) do
    quote do
      # import Exmachina.Neuron
      alias Exmachina.Neuron
      alias Neuron.Process
      alias Neuron.Dendrites
      alias Neuron.Axon

      # @learning_rate 3.0

      defstruct dendrites: nil, axon: nil, process_pid: nil, target: nil

      def start_link(args), do: Process.start_link([neuron_type: __MODULE__] ++ args)

      defdelegate set_target(pid, output_pid),     to: Process
      defdelegate get_weight_for(pid, output_pid), to: Process
      defdelegate get_last_activity(pid),          to: Process
      defdelegate activate(pid, activity),         to: Process

      def new(num_inputs: num_inputs, output_pids: output_pids, process_pid: process_pid) do
        %__MODULE__{dendrites: Dendrites.new(num_inputs), axon: Axon.new(output_pids), process_pid: process_pid}
      end

      def record_new_target(%__MODULE__{} = neuron, target), do:          Neuron.record_new_target(neuron, target)
      def get_weight_by_pid(%__MODULE__{} = neuron, pid), do:             Neuron.get_weight_by_pid(neuron, pid)
      def get_activity(%__MODULE__{} = neuron), do:                       Neuron.get_activity(neuron)
      def record_activation(%__MODULE__{} = neuron, activity, from), do:  Neuron.record_activation(neuron, activity, from)

      def compute_activity(%__MODULE__{} = neuron), do:                   neuron
      def send_forward_and_receive_errors(%__MODULE__{} = neuron), do:    neuron
      def send_error_backward(%__MODULE__{} = neuron), do:                neuron
      def adjust_weights(%__MODULE__{} = neuron), do:                     neuron

      defoverridable [compute_activity: 1, send_forward_and_receive_errors: 1, send_error_backward: 1, adjust_weights: 1]
    end
  end

  defdelegate activate(pid, activity), to: Process

  def record_new_target(%{} = neuron, target) do
    %{neuron | target: target}
  end

  def get_weight_by_pid(%{axon: axon}, pid) do
    axon.output_weights[pid]
  end

  def get_activity(%{dendrites: dendrites}) do
    dendrites.activity
  end

  def record_activation(%{dendrites: dendrites, process_pid: process_pid} = neuron, activity, from) do
    dendrites = Dendrites.add_input_activity(activity, from, dendrites)
    if map_size(dendrites.input_activities) == dendrites.num_inputs, do: Process.fire(process_pid)

    %{neuron | dendrites: dendrites}
  end
end
