defmodule Mix.Tasks.Step1ReadPrint do
  def run(_), do: Collie.Steps1ReadPrint.loop()
end
