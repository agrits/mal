defmodule Mix.Tasks.Step2Eval do
  def run(_), do: Collie.Steps2Eval.loop()
end
