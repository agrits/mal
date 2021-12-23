defmodule Collie.Atom do
  def new(ast) do
    {:ok, pid} = Agent.start_link(fn -> ast end)
    {:atom, pid}
  end

  def atom?({:atom, _}), do: true
  def atom?(_), do: false

  def deref({:atom, pid}), do: Agent.get(pid, & &1)

  def reset!({:atom, pid}, new_value) do
    Agent.update(pid, fn _ -> new_value end)
    new_value
  end

  def swap!([{:atom, pid}, fun | args]) do
    new_value = apply(fun, [[deref({:atom, pid})| args]])
    {:atom, pid} |> reset!(new_value)
  end
end
