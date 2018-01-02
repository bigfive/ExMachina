defmodule Exmachina do
  def test do
    {:ok, o1} = Exmachina.OutputNeuron.start_link(num_inputs: 4)
    {:ok, o2} = Exmachina.OutputNeuron.start_link(num_inputs: 4)
    {:ok, o3} = Exmachina.OutputNeuron.start_link(num_inputs: 4)

    {:ok, h1} = Exmachina.Neuron.start_link(num_inputs: 8, output_pids: [o1, o2, o3])
    {:ok, h2} = Exmachina.Neuron.start_link(num_inputs: 8, output_pids: [o1, o2, o3])
    {:ok, h3} = Exmachina.Neuron.start_link(num_inputs: 8, output_pids: [o1, o2, o3])
    {:ok, h4} = Exmachina.Neuron.start_link(num_inputs: 8, output_pids: [o1, o2, o3])

    {:ok, i1} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i2} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i3} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i4} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i5} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i6} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i7} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])
    {:ok, i8} = Exmachina.Neuron.start_link(num_inputs: 1, output_pids: [h1, h2, h3, h4])

    # training example 1

    Exmachina.OutputNeuron.set_target(o1, 1)
    Exmachina.OutputNeuron.set_target(o2, 0)
    Exmachina.OutputNeuron.set_target(o3, 0)

    example = %{
      i1 => (1 - :rand.uniform() * 2),
      i2 => (1 - :rand.uniform() * 2),
      i3 => (1 - :rand.uniform() * 2),
      i4 => (1 - :rand.uniform() * 2),
      i5 => (1 - :rand.uniform() * 2),
      i6 => (1 - :rand.uniform() * 2),
      i7 => (1 - :rand.uniform() * 2),
      i8 => (1 - :rand.uniform() * 2),
    }

    for index <- 1..1000 do
      example
      |> Task.async_stream(fn {node, value} -> Exmachina.Neuron.activate(node, value) end)
      |> Stream.run()

      ov1 = Exmachina.OutputNeuron.get_last_activity(o1)
      ov2 = Exmachina.OutputNeuron.get_last_activity(o2)
      ov3 = Exmachina.OutputNeuron.get_last_activity(o3)

      if rem(index, 100) == 0, do: IO.inspect [ov1, ov2, ov3]
    end

    :ok
  end
end
