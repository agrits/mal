defmodule Mix.Tasks.Step0Repl do
  def run(_), do: Collie.Steps0Repl.loop()
end
