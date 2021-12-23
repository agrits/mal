defmodule Mix.Tasks.Step3Env do
  def run(_), do: Collie.Steps3Env.loop()
end
