defmodule Mix.Tasks.Learn do
  use Mix.Task

  @shortdoc "Runs the Exmachina.learn/0 function"
  def run(_) do
    Exmachina.learn()
  end
end
