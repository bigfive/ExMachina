defmodule Exmachina.OutputNeuron do
  alias Exmachina.Neuron.Soma
  alias Exmachina.Neuron.Dendrites

  use GenServer

  defstruct soma: nil, target: nil

  def start_link(num_inputs: num_inputs) do
    bias = init_weight() - 2.0
    soma = %Soma{num_inputs: num_inputs, bias: bias}

    GenServer.start_link(__MODULE__, %__MODULE__{soma: soma})
  end

  def set_target(pid, target) do
    GenServer.call(pid, {:set_target, target})
  end

  def get_last_activity(pid) do
    GenServer.call(pid, :get_last_activity)
  end

  def handle_call({:activate, activity}, from, %__MODULE__{soma: soma} = state) do
    soma = Soma.add_input_activity(soma, activity, from)
    fire_if_all_received(soma.input_activities, soma.num_inputs)

    {:noreply, %{state | soma: soma}}
  end

  def handle_call({:set_target, target}, _from, state) do
    {:reply, :ok, %{state | target: target}}
  end

  def handle_call(:get_last_activity, _from, %__MODULE__{soma: soma} = state) do
    {:reply, soma.activity, state}
  end

  def handle_cast(:fire, %__MODULE__{soma: soma, target: target} = state) do
    with(
      soma  <- Soma.compute_activity(soma),
      error <- mimic_error_response(soma.activity, target),
      soma  <- Soma.reply_with_error(soma, error)
    ) do
      {:noreply, %{state | soma: soma}}
    end
  end

  defp init_weight, do: (:rand.uniform() * 2) - 1.0

  defp fire_if_all_received(input_activities, num_inputs) do
    if map_size(input_activities) == num_inputs, do: GenServer.cast(self(), :fire)
  end

  defp mimic_error_response(activity, target) do
    weight = 1
    error = -(target - activity)
    %{self() => {error, weight}}
  end
end
