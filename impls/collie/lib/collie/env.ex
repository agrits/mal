defmodule Collie.Env do
  alias Collie.{Core, Types}

  def new(outer \\ nil) do
    {:ok, pid} = Agent.start_link(fn -> %{data: Core.namespace(), outer: outer} end, [])
    pid
  end

  def set(pid, {:symbol, key}, value) do
    Agent.update(pid, fn env -> %{outer: env.outer, data: Map.put(env.data, key, value)} end)
  end

  defp find(pid, {:symbol, key}) do
    env = Agent.get(pid, & &1)

    case Map.has_key?(env.data, key) do
      false -> try_outer_find(env, Types.symbol(key))
      true -> Map.get(env.data, key)
    end
  end

  defp try_outer_find(env, {:symbol, key}) do
    case env.outer do
      nil -> {:error, :no_key}
      outer -> find(outer, Types.symbol(key))
    end
  end

  def get(pid, {:symbol, key}) do
    case find(pid, {:symbol, key}) do
      {:error, :no_key} -> throw({:error, "#{key} not found."})
      value -> value
    end
  end
end
