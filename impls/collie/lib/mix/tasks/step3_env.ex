defmodule Mix.Tasks.Step3Env do
  def run(_), do: Collie.Steps.Step3Env.loop()
end
