defmodule Collie.Steps3Env do
  alias Collie.{Env, Printer, Reader, Types}

  defp read(s), do: Reader.read_str(s)

  def eval_ast({:symbol, _} = key, env) do
    Env.get(env, key)
  end

  def eval_ast({:vector, ast}, env), do: eval_ast(ast, env) |> Types.vector()

  def eval_ast([{:symbol, "do"} | rest], env) do
    rest
    |> Enum.reduce(fn ast -> eval_ast(ast, env) end)
  end

  def eval_ast([{:symbol, "if"}, condition, if_true, if_false]) do
    case eval_ast(condition)  do
      true -> eval_ast(if_true)
      v when v in [false, nil] -> eval_ast(if_false)
    end
  end

  def eval_ast([{:symbol, "fn*"}, binds, exprs], env) do
    fn params ->
      inner_env = Env.new(env)

      Enum.zip(binds, params)
        |> Enum.each(fn {key, value} -> Env.set(inner_env, key, value) end)

      eval_ast(exprs, inner_env)
    end
  end

  def eval_ast(ast, env) when is_list(ast) do
    Enum.map(ast, fn x -> eval(x, env) end)
  end

  def eval_ast(ast, env) when is_map(ast) do
    ast
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {k, eval(v, env)} end)
    |> Enum.into(%{})
  end

  def eval_ast(ast, _env) do
    ast
  end

  def eval(ast, env) when is_list(ast) do
    case ast do
      [] ->
        ast

      [{:symbol, "def!"}, {:symbol, _} = name_ast, body] ->
        do_def(name_ast, body, env)

      [{:symbol, "let*"}, {:vector, bindings}, ast] ->
        do_let(bindings, ast, env)

      [{:symbol, "let*"}, bindings, ast] ->
        do_let(bindings, ast, env)

      _ ->
        [f | args] = eval_ast(ast, env)
        apply(f, [args])
    end
  end

  def eval(ast, env), do: eval_ast(ast, env)

  defp do_def({:symbol, _} = name_ast, body, env) do
    eval(body, env)
    |> tap(&Env.set(env, name_ast, &1))
  end

  defp do_let(bindings, ast, env) do
    inner_env = Env.new(env)

    bindings
    |> Enum.chunk_every(2)
    |> Enum.each(fn [key, value] -> Env.set(inner_env, key, eval(value, inner_env)) end)

    eval(ast, inner_env)
  end

  defp print(exp), do: Printer.pr_str(exp)

  defp rep(str, env) do
    str
    |> read
    |> eval(env)
    |> print
  catch
    e -> "#{inspect(e)}"
  end

  def loop() do
    env = Env.new()
    loop(env)
  end

  def loop(env) do
    try do
      IO.gets("user> ")
      |> String.trim("\n")
      |> rep(env)
      |> IO.puts()
    rescue
      e -> IO.puts(inspect({:error, inspect(e)}))
    end

    loop(env)
  end
end
