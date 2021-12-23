defmodule Collie.Steps2Eval do
  alias Collie.{Printer, Reader, Types}

  defp read(s), do: Reader.read_str(s)

  defp eval_ast(ast, env \\ %{})

  defp eval_ast({:symbol, ast}, env) do
    case Map.get(env, ast) do
      nil -> throw({:error, "#{inspect(ast)} not found"})
      value -> value
    end
  end

  defp eval_ast({:vector, ast}, env), do: eval_ast(ast, env) |> Types.vector()

  defp eval_ast(ast, env) when is_list(ast), do: Enum.map(ast, fn x -> eval(x, env) end)

  defp eval_ast(ast, env) when is_map(ast) do
    ast
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {k, eval(v, env)} end)
    |> Enum.into(%{})
  end

  defp eval_ast(ast, _env) do
    ast
  end

  defp eval(ast, env \\ @erlang_core)

  defp eval(ast, env) when is_list(ast) do
    case Enum.empty?(ast) do
      true ->
        ast

      false ->
        [f | args] = eval_ast(ast, env)
        apply(f, [args])
    end
  end

  defp eval(ast, env), do: eval_ast(ast, env)

  defp print(exp), do: Printer.pr_str(exp)

  def rep(str) do
    str
    |> read
    |> eval(erlang_core())
    |> print
  catch
    e -> "#{inspect(e)}"
  end

  def loop() do
    try do
      IO.gets("user> ")
      |> String.trim("\n")
      |> rep()
      |> IO.puts()
    rescue
      e -> IO.puts(inspect({:error, inspect(e)}))
    end

    loop()
  end

  defp erlang_core() do
    :erlang.module_info(:exports)
    |> Enum.map(&elem(&1, 0))
    |> Enum.map(fn name -> {Atom.to_string(name), fn args -> apply(:erlang, name, args) end} end)
    |> Enum.into(%{})
  end
end
