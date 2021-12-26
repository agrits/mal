defmodule Mix.Tasks.Step1ReadPrint do
  def run(_), do: Collie.Steps.Step1ReadPrint.loop()
end
