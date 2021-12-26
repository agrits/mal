defmodule Mix.Tasks.Step2Eval do
  def run(_), do: Collie.Steps.Step2Eval.loop()
end
